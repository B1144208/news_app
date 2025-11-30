import requests
from bs4 import BeautifulSoup
import json
from datetime import datetime
import time
from pathlib import Path
from functools import partial

from newsCrawler import utils
from newsCrawler.utils import errorlog
from newsCrawler.object import CrawlerData, CrawlerQueue, ErrorLog

BASE_URL = "https://www.npr.org"

# 新聞頻道列表
CHANNELS = [
    {"name": "National", "url": "/sections/national/", "group": "National"},
    {"name": "World", "url": "/sections/world/", "group": "World"},
    {"name": "Politics", "url": "/sections/politics/", "group": "Politics"},
    {"name": "Business", "url": "/sections/business/", "group": "Business"},
    {"name": "Health", "url": "/sections/health/", "group": "Health"},
    {"name": "Science", "url": "/sections/science/", "group": "Science"},
    {"name": "Climate", "url": "/sections/climate/", "group": "Climate"},
    {"name": "Race", "url": "/sections/codeswitch/", "group": "Race"}
]


def run(crawler_data):
    """主程式入口"""
    
    # create crawlerData
    crawlerData = crawler_data

    # create newsQueue
    newsQueue = CrawlerQueue(
        name="NPR",
        kind="news",
        crawler_data=crawlerData,
        save_into_json=True
    )
    
    # create ErrorLog
    ErrorLog(
        name="NPR-errLog",
        path=Path(__file__).resolve().parent,
        fn_map=[
            [start_news_collection, ["BASE_URL", "crawlerData", "newsQueue"]],
            [get_news_list, ["channel_name", "channel_url", "group", "crawlerData", "newsQueue"]],
            [get_news_detail, ["url"]]
        ],
        # 先傳 json 無法儲存的資料，新建的 crawlerData, newsQueue
        init_data={
            "crawlerData": crawlerData,
            "newsQueue": newsQueue
        },
        entry=partial(start_news_collection, BASE_URL, crawlerData, newsQueue)
    )

    newsQueue._graceful_backup()
    newsQueue.stop_autobackup()

    print("========== NPR_NEWS 擷取完成 ==========\n")
    return


def start_news_collection(BASE_URL: str, crawlerData, newsQueue):
    """開始收集所有頻道的新聞"""
    
    # push-fn
    errorlog("push-fn", start_news_collection, [
        {"BASE_URL": BASE_URL}
    ])

    print("🚀 開始載入 NPR 新聞...")

    try:
        # set CHANNELS to data
        errorlog("set_data", "CHANNELS", CHANNELS)

        for channel in CHANNELS:
            print(f"\n開始爬取 {channel['name']} 頻道...")
            
            try:
                get_news_list(
                    channel['name'], 
                    channel['url'], 
                    channel['group'],
                    crawlerData,
                    newsQueue
                )
                print(f"✓ {channel['name']} 完成")
                
            except Exception as e:
                print(f"✗ {channel['name']} 爬取失敗: {e}")
            
            # pop channel from CHANNELS
            errorlog("pop_list", "CHANNELS")
            
            time.sleep(1)

    except Exception as e:
        print(f"❌ start_news_collection 發生錯誤: {e}")
        return
    
    # pop-fn
    errorlog("pop-fn")
    
    return


def get_news_list(channel_name, channel_url, group, crawlerData, newsQueue):
    """從指定頻道的 featured 和 overflow 區塊獲取新聞列表"""
    
    # push-fn
    errorlog("push-fn", get_news_list, [
        {"channel_name": channel_name},
        {"channel_url": channel_url},
        {"group": group}
    ])

    full_url = BASE_URL + channel_url
    
    try:
        res = requests.get(full_url, headers={"User-Agent": "Mozilla/5.0"})
        res.raise_for_status()
        soup = BeautifulSoup(res.text, "html.parser")

        # 找到 featured 和 overflow 區塊
        featured_section = soup.select_one("#featured")
        overflow_section = soup.select_one("#overflow")

        # 合併兩個區塊的文章
        articles = []
        if featured_section:
            articles.extend(featured_section.select("article.item"))
        if overflow_section:
            articles.extend(overflow_section.select("article.item"))

        print(f"正在爬取 {channel_name} 頻道,找到 {len(articles)} 篇文章...")

        # set articles to data
        errorlog("set_data", "articles", [art.get("data-id", f"article_{i}") for i, art in enumerate(articles)])

        for i, art in enumerate(articles):
            # 獲取標題
            title_tag = art.select_one(".title a")
            if not title_tag:
                # pop article from articles
                errorlog("pop_list", "articles")
                continue

            title = title_tag.get_text(strip=True)
            url = title_tag.get("href", "")
            if not url.startswith("http"):
                url = BASE_URL + url

            # 封面圖片
            cover_img = None
            item_image_div = art.select_one(".item-image")
            if item_image_div:
                img_tag = item_image_div.select_one("img[src][alt]")
                if img_tag:
                    cover_img = {
                        "src": img_tag.get("src"),
                        "alt": img_tag.get("alt", "")
                    }

            # 外層日期(備用)
            date_tag = art.select_one("time")
            publish_date = None
            if date_tag and date_tag.has_attr("datetime"):
                try:
                    dt = datetime.fromisoformat(date_tag["datetime"].replace("Z", "+00:00"))
                    publish_date = dt.strftime("%Y/%m/%d %H:%M:%S")
                except:
                    publish_date = date_tag.get_text(strip=True)

            # 取得詳細內容與內文日期
            detail, inner_publish_date = get_news_detail(url)
            if inner_publish_date:
                publish_date = inner_publish_date  # 以內文日期為主

            article_data = {
                "url": url,
                "group": group,
                "channel": "NPR",
                "cover_img": cover_img,
                "title": title,
                "publish_date": publish_date,
                "detail": detail,
                "keyword": None,
                "comment": None
            }

            # push to newsQueue
            newsQueue.push_one(article_data)

            # pop article from articles (for 最後一圈前也要 pop)
            if i == len(articles) - 1:
                errorlog("delete_data", "articles")
            else:
                errorlog("pop_list", "articles")

            time.sleep(0.5)

    except Exception as e:
        print(f"❌ get_news_list 發生錯誤: {e}")
        # pop-fn before return
        errorlog("pop-fn")
        return
    
    # pop-fn
    errorlog("pop-fn")
    
    return


def get_news_detail(url):
    """獲取新聞詳細內容與內文日期"""
    
    # push-fn
    errorlog("push-fn", get_news_detail, [
        {"url": url}
    ])

    details = []
    publish_date = None

    try:
        res = requests.get(url, headers={"User-Agent": "Mozilla/5.0"})
        res.raise_for_status()
        soup = BeautifulSoup(res.text, "html.parser")

        # 從內文抓取 datetime
        dateblock = soup.select_one(".dateblock time[datetime]")
        if dateblock and dateblock.has_attr("datetime"):
            raw_dt = dateblock["datetime"]
            try:
                date_part, time_part = raw_dt.split("T")
                time_part = time_part.split("-")[0]  # 移除時區部分
                publish_date = f"{date_part.replace('-', '/')} {time_part}"
            except:
                publish_date = None

        # 取得內文
        story_div = soup.select_one("article.story")
        if not story_div:
            # pop-fn before return
            errorlog("pop-fn")
            return details, publish_date

        storytext_div = story_div.select_one(".storytext, div[id='storytext']")
        if not storytext_div:
            storytext_div = story_div

        content_elements = storytext_div.select("p, img")

        for elem in content_elements:
            if elem.name == "p":
                text = elem.get_text(strip=True)
                if text and len(text) > 5:
                    details.append({"text": text})
            elif elem.name == "img":
                img_src = elem.get("src")
                img_alt = elem.get("alt", "")
                if img_src:
                    details.append({
                        "img": {
                            "src": img_src,
                            "alt": img_alt
                        }
                    })

    except Exception as e:
        print(f"獲取詳細內容時發生錯誤 ({url}): {e}")
    
    # pop-fn
    errorlog("pop-fn")
    
    return details, publish_date


def get_channel_data():
    """生成頻道資料"""
    channel_data = []
    for channel in CHANNELS:
        channel_data.append({
            "url": BASE_URL + channel["url"],
            "img": "https://media.npr.org/include/images/facebook-default-wide.jpg",
            "name": f"NPR {channel['name']}",
            "type": None,
            "introduce": f"Latest {channel['name'].lower()} news from NPR."
        })
    return channel_data


if __name__ == "__main__":
    crawlerData = utils.CrawlerData(channel_id=4)
    run(crawlerData)