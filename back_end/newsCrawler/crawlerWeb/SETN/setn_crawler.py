import requests
from bs4 import BeautifulSoup
import json
from urllib.parse import urljoin

headers = {"User-Agent": "Mozilla/5.0"}

# Parser 區
def parse_detail(news_soup):
    """解析新聞內文與封面圖"""
    detail = []
    cover_img = None

    # ckuse 結構
    ckuse = news_soup.select_one("#ckuse")
    if ckuse:
        blocks = ckuse.select("p, img")
        for block in blocks:
            if block.name == "p":
                text = block.get_text(strip=True)
                if text:
                    detail.append({"text": text})
            elif block.name == "img":
                img_src = block.get("src")
                img_alt = block.get("alt", "")
                if img_src:
                    if not cover_img:
                        cover_img = {"src": img_src, "alt": img_alt if img_alt else None}
                    detail.append({"img": {"src": img_src, "alt": img_alt if img_alt else None}})
        return cover_img, detail

    # printdiv 結構
    printdiv = news_soup.select_one("article.printdiv")
    if printdiv:
        blocks = printdiv.select("p, img")
        for block in blocks:
            if block.name == "p":
                text = block.get_text(strip=True)
                if text:
                    detail.append({"text": text})
            elif block.name == "img":
                img_src = block.get("src")
                img_alt = block.get("alt", "")
                if img_src:
                    if not cover_img:
                        cover_img = {"src": img_src, "alt": img_alt if img_alt else None}
                    detail.append({"img": {"src": img_src, "alt": img_alt if img_alt else None}})
        return cover_img, detail

    return cover_img, detail


def parse_publish_date(news_soup):
    """解析新聞時間"""
    time_tag = news_soup.select_one("time.page_date")  # ckuse
    if time_tag:
        return time_tag.get_text(strip=True)

    time_tag = news_soup.select_one("div.newsPage.newsTime.printdiv time")  # printdiv
    if time_tag:
        return time_tag.get_text(strip=True)

    return None


def parse_author(news_soup):
    """解析文章作者資訊"""
    author_tag = news_soup.select_one("a.reporter")
    if author_tag:
        author_url = "https://www.setn.com" + author_tag["href"] if author_tag["href"].startswith("/") else author_tag["href"]
        author_name = author_tag.text.strip()
        return {
            "url": author_url,
            "img": None,
            "name": author_name,
            "type": None,
            "introduce": ""
        }
    return None


def parse_channels():
    """解析頻道清單"""
    url = "https://www.setn.com/viewall.aspx"
    res = requests.get(url, headers=headers)
    soup = BeautifulSoup(res.text, "html.parser")

    channels = []

    # 選取所有 qTab 和 qTab active
    channel_tabs = soup.select("td.qTab, td.qTab.active")

    for tab in channel_tabs:
        a_tag = tab.find("a")
        if a_tag:
            span = a_tag.find("span")
            if span:
                channel_name = span.text.strip()
                href = a_tag.get("href", "")

                # 處理完整 URL
                if href.startswith("http"):
                    channel_url = href
                else:
                    channel_url = urljoin("https://www.setn.com/", href)

                channels.append({
                    "name": channel_name,
                    "url": channel_url
                })

    return channels


def parse_news_list(soup, channel_url):
    """根據頻道 URL 選擇對應的解析器"""
    news_items = []

    # 判斷是哪種頻道類型
    if "star.setn.com" in channel_url:
        # 娛樂頻道格式
        items = soup.select("div.newsItems")
        for item in items:
            try:
                # 封面圖
                img_tag = item.select_one("div.imageContainer img")
                img_src = img_tag.get("data-src") or img_tag.get("src") if img_tag else None
                img_alt = img_tag.get("alt", "") if img_tag else ""

                # 標題
                title_tag = item.select_one("h3.newsTitle a")
                title = title_tag.text.strip() if title_tag else ""
                link = title_tag.get("href", "") if title_tag else ""

                # 時間
                time_tag = item.select_one("div.newsTime time")
                publish_time = time_tag.text.strip() if time_tag else ""

                if title and link:
                    news_items.append({
                        "title": title,
                        "link": link if link.startswith("http") else urljoin("https://www.setn.com/", link),
                        "img_src": img_src,
                        "img_alt": img_alt if img_alt else None,
                        "publish_time": publish_time
                    })
            except Exception as e:
                print(f"    解析娛樂頻道新聞項目失敗: {str(e)}")
                continue

    elif "health.setn.com" in channel_url:
        # 健康頻道格式
        items = soup.select("div.newsItems")
        for item in items:
            try:
                link_tag = item.select_one("a")
                if not link_tag:
                    continue

                # 封面圖
                img_tag = link_tag.select_one("div.image-container img")
                img_src = img_tag.get("data-original") or img_tag.get("src") if img_tag else None
                img_alt = img_tag.get("alt", "") if img_tag else ""

                # 標題
                title_tag = link_tag.select_one("div.newsItemsContent h3")
                title = title_tag.text.strip() if title_tag else ""

                # 時間
                time_tag = link_tag.select_one("span.newsTimer")
                publish_time = time_tag.text.strip() if time_tag else ""

                # 連結
                link = link_tag.get("href", "")

                if title and link:
                    news_items.append({
                        "title": title,
                        "link": link if link.startswith("http") else urljoin("https://www.setn.com/", link),
                        "img_src": img_src,
                        "img_alt": img_alt if img_alt else None,
                        "publish_time": publish_time
                    })
            except Exception as e:
                print(f"    解析健康頻道新聞項目失敗: {str(e)}")
                continue

    elif "fuhouse.setn.com" in channel_url:
        # 房產頻道格式
        items = soup.select("div.all_three_list")
        for item in items:
            try:
                # 跳過廣告區塊
                if "all_three_list_ad" in item.get("class", []):
                    continue

                link_tag = item.select_one("a")
                if not link_tag:
                    continue

                # 封面圖
                img_tag = item.select_one("div.img_box img")
                img_src = img_tag.get("src") if img_tag else None
                img_alt = img_tag.get("alt", "") if img_tag else ""

                # 標題
                title_tag = item.select_one("div.all_three_wordbox h2.title-word")
                title = title_tag.text.strip() if title_tag else ""

                # 時間
                time_tag = item.select_one("div.all_three_wordbox time")
                publish_time = time_tag.text.strip() if time_tag else ""

                # 連結
                link = link_tag.get("href", "")

                if title and link:
                    news_items.append({
                        "title": title,
                        "link": link if link.startswith("http") else urljoin("https://fuhouse.setn.com/", link),
                        "img_src": img_src,
                        "img_alt": img_alt if img_alt else None,
                        "publish_time": publish_time
                    })
            except Exception as e:
                print(f"    解析房產頻道新聞項目失敗: {str(e)}")
                continue

    elif "baodao.setn.com" in channel_url:
        # 寶島神很大頻道格式
        items = soup.select("div.PnewsBox")
        for item in items:
            try:
                # 封面圖
                img_tag = item.select_one("div.PnewsPic img")
                img_src = img_tag.get("src") if img_tag else None
                img_alt = img_tag.get("alt", "") if img_tag else ""

                # 標題
                title_tag = item.select_one("p.newsTitle a")
                title = title_tag.text.strip() if title_tag else ""
                link = title_tag.get("href", "") if title_tag else ""

                # 時間
                time_tag = item.select_one("time.date")
                publish_time = time_tag.text.strip() if time_tag else ""

                if title and link:
                    news_items.append({
                        "title": title,
                        "link": link if link.startswith("http") else urljoin("https://baodao.setn.com/", link),
                        "img_src": img_src,
                        "img_alt": img_alt if img_alt else None,
                        "publish_time": publish_time
                    })
            except Exception as e:
                print(f"    解析寶島神很大頻道新聞項目失敗: {str(e)}")
                continue
    else:
        # 一般頻道格式 (預設)
        items = soup.select("div.col-sm-12 a.gt")
        for item in items:
            try:
                title = item.text.strip()
                link = item.get("href", "")

                if title and link:
                    news_items.append({
                        "title": title,
                        "link": link if link.startswith("http") else urljoin("https://www.setn.com/", link),
                        "img_src": None,
                        "img_alt": None,
                        "publish_time": ""
                    })
            except Exception as e:
                print(f"    解析一般頻道新聞項目失敗: {str(e)}")
                continue

    return news_items


def crawl_channel_news(channel_name, channel_url, limit=20):
    """爬取單一頻道的新聞"""
    print(f"正在爬取頻道: {channel_name} ({channel_url})")

    try:
        response = requests.get(channel_url, headers=headers)
        soup = BeautifulSoup(response.text, "html.parser")

        # 使用對應的解析器取得新聞列表
        news_items = parse_news_list(soup, channel_url)

        news_list = []

        for item in news_items[:limit]:
            try:
                title = item["title"]
                link = item["link"]

                # 爬取新聞內頁
                news_res = requests.get(link, headers=headers)
                news_soup = BeautifulSoup(news_res.text, "html.parser")

                publish_date = parse_publish_date(news_soup) or item["publish_time"]
                cover_img, detail = parse_detail(news_soup)

                # 如果內頁沒有封面圖,使用列表頁的圖
                if not cover_img and item["img_src"]:
                    cover_img = {"src": item["img_src"], "alt": item["img_alt"]}

                # 新格式：channel改為group，channel固定為"三立新聞"
                news_item = {
                    "url": link,
                    "group": channel_name,  # 原本的channel改為group
                    "channel": "三立新聞",   # channel固定為"三立新聞"
                    "cover_img": cover_img,
                    "title": title,
                    "publish_date": publish_date,
                    "detail": detail,
                    "keyword": [],
                    "comment": None,  # 沒有就標null
                }
                news_list.append(news_item)

            except Exception as e:
                print(f"  ✗ 爬取新聞失敗: {str(e)}")
                continue

        return news_list

    except Exception as e:
        print(f"  ✗ 爬取頻道失敗: {str(e)}")
        return []


def crawl_setn():
    """主程式:爬取所有頻道的新聞"""

    # 1. 解析頻道清單
    print("正在解析頻道清單...")
    channels = parse_channels()
    print(f"找到 {len(channels)} 個頻道\n")

    # 2. 爬取所有頻道的新聞
    ALL_NEWS = []
    CHANNEL_DATA = []

    for channel in channels:
        news_list = crawl_channel_news(channel["name"], channel["url"], limit=20)
        ALL_NEWS.extend(news_list)

        # 收集頻道資訊
        channel_item = {
            "url": channel["url"],
            "img": None,
            "name": channel["name"],
            "type": None,
            "introduce": ""
        }
        if channel_item not in CHANNEL_DATA:
            CHANNEL_DATA.append(channel_item)

        print(f"{channel['name']}: {len(news_list)} 篇新聞\n")

    # 3. 輸出 JSON (新格式：包裹在data陣列中)
    with open("4_NEWS.json", "w", encoding="utf-8") as f:
        json.dump({"data": ALL_NEWS}, f, ensure_ascii=False, indent=2)

    with open("4_CHANNEL.json", "w", encoding="utf-8") as f:
        json.dump({"data": CHANNEL_DATA}, f, ensure_ascii=False, indent=2)

    print(f"\n爬取完成!")
    print(f"總共爬取 {len(ALL_NEWS)} 篇新聞")
    print(f"已輸出 4_NEWS.json 與 4_CHANNEL.json")


if __name__ == "__main__":
    crawl_setn()