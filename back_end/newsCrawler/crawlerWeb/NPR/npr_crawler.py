import requests
from bs4 import BeautifulSoup
import json
from datetime import datetime
import time

BASE_URL = "https://www.npr.org"

# 新聞頻道列表
CHANNELS = [
    {"name": "National", "url": "/sections/national/"},
    {"name": "World", "url": "/sections/world/"},
    {"name": "Politics", "url": "/sections/politics/"},
    {"name": "Business", "url": "/sections/business/"},
    {"name": "Health", "url": "/sections/health/"},
    {"name": "Science", "url": "/sections/science/"},
    {"name": "Climate", "url": "/sections/climate/"},
    {"name": "Race", "url": "/sections/codeswitch/"}
]


def get_news_list(channel_name, channel_url):
    #從指定頻道的 featured 和 overflow 區塊獲取新聞列表
    full_url = BASE_URL + channel_url
    res = requests.get(full_url, headers={"User-Agent": "Mozilla/5.0"})
    res.raise_for_status()
    soup = BeautifulSoup(res.text, "html.parser")

    news_items = []

    # 找到 featured 和 overflow 區塊
    featured_section = soup.select_one("#featured")
    overflow_section = soup.select_one("#overflow")

    # 合併兩個區塊的文章
    articles = []
    if featured_section:
        articles.extend(featured_section.select("article.item"))
    if overflow_section:
        articles.extend(overflow_section.select("article.item"))

    print(f"正在爬取 {channel_name} 頻道，找到 {len(articles)} 篇文章...")

    for art in articles:
        # 獲取標題
        title_tag = art.select_one(".title a")
        if not title_tag:
            continue

        title = title_tag.get_text(strip=True)
        url = title_tag.get("href", "")
        if not url.startswith("http"):
            url = BASE_URL + url

        # 封面圖片
        cover_img = {}
        item_image_div = art.select_one(".item-image")
        if item_image_div:
            img_tag = item_image_div.select_one("img[src][alt]")
            if img_tag:
                cover_img = {
                    "src": img_tag.get("src"),
                    "alt": img_tag.get("alt")
                }

        # 外層日期（備用）
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

        news_items.append({
            "url": url,
            "channel": channel_name,
            "cover_img": cover_img if cover_img else None,
            "title": title,
            "publish_date": publish_date,
            "detail": detail,
            "comment": []
        })

        time.sleep(0.5)

    return news_items


def get_news_detail(url):
    #獲取新聞詳細內容與內文日期
    try:
        res = requests.get(url, headers={"User-Agent": "Mozilla/5.0"})
        res.raise_for_status()
        soup = BeautifulSoup(res.text, "html.parser")

        details = []
        publish_date = None

        # 從內文抓取 datetime
        dateblock = soup.select_one(".dateblock time[datetime]")
        if dateblock and dateblock.has_attr("datetime"):
            raw_dt = dateblock["datetime"]
            try:
                date_part, time_part = raw_dt.split("T")
                time_part = time_part.split("-")[0]  # 移除時區部分
                publish_date = f"{date_part.replace('-', '/') } {time_part}"
            except:
                publish_date = None

        # 取得內文
        story_div = soup.select_one("article.story")
        if not story_div:
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
                img_alt = elem.get("alt")
                if img_src:
                    details.append({
                        "img": {
                            "src": img_src,
                            "alt": img_alt
                        }
                    })

        return details, publish_date
    except Exception as e:
        print(f"獲取詳細內容時發生錯誤 ({url}): {e}")
        return [], None


def get_channel_data():
    #生成頻道資料
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


def main():
    all_news = []

    for channel in CHANNELS:
        print(f"\n開始爬取 {channel['name']} 頻道...")
        try:
            news_list = get_news_list(channel['name'], channel['url'])
            all_news.extend(news_list)
            print(f"✓ {channel['name']} 完成，共 {len(news_list)} 篇")
        except Exception as e:
            print(f"✗ {channel['name']} 爬取失敗: {e}")
        time.sleep(1)

    channel_data = get_channel_data()

    with open("NEWS_DATA.json", "w", encoding="utf-8") as f:
        json.dump(all_news, f, ensure_ascii=False, indent=2)

    with open("CHANNEL_DATA.json", "w", encoding="utf-8") as f:
        json.dump(channel_data, f, ensure_ascii=False, indent=2)

    print(f"\n完成！共爬取 {len(all_news)} 篇新聞")
    print("輸出檔案：NEWS_DATA.json, CHANNEL_DATA.json")


if __name__ == "__main__":
    main()
