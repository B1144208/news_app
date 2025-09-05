import requests
from bs4 import BeautifulSoup
from datetime import datetime

BASE_URL = "https://www.bbc.com"

def get_channel_info():
    return {
        "name": "BBC",
        "url": BASE_URL + "/news"
    }

def fetch_news_list(limit=5):
    url = BASE_URL + "/news"
    response = requests.get(url)
    response.encoding = "utf-8"
    soup = BeautifulSoup(response.text, "html.parser")

    news_list = []
    seen_links = set()
    for link in soup.select("a[href*='/news/articles/']"):
        href = link.get("href")
        if not href or href in seen_links:
            continue
        seen_links.add(href)

        full_url = BASE_URL + href if href.startswith("/") else href
        news = get_news_info(full_url)
        if news:
            news_list.append(news)
        if len(news_list) >= limit:
            break

    return news_list


def get_news_info(url):
    try:
        response = requests.get(url)
        response.encoding = "utf-8"
        soup = BeautifulSoup(response.text, "html.parser")

        # title
        title_tag = soup.select_one("h1")
        title = title_tag.get_text(strip=True) if title_tag else "無標題"

        # cover image
        cover_tag = soup.select_one("img")
        cover_img = {
            "src": cover_tag["src"] if cover_tag and cover_tag.has_attr("src") else "",
            "alt": cover_tag.get("alt", "") if cover_tag else ""
        }

        # content
        detail = []
        for p in soup.select("article p"):
            text = p.get_text(strip=True)
            if text:
                detail.append({
                    "text": text,
                    "img": {"src": "", "alt": ""}
                })

        # 發布時間
        time_tag = soup.select_one("time")
        publish_date = ""
        if time_tag and time_tag.has_attr("datetime"):
            publish_date = time_tag["datetime"]
        else:
            publish_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        return {
            "url": url,
            "group": "BBC新聞",
            "channel": "BBC",
            "cover_img": cover_img,
            "news_title": title,
            "publish_date": publish_date,
            "location": "",
            "detail": detail,
            "keyword": [""]   # BBC 暫時沒抓關鍵字
        }
    except Exception as e:
        print(f"❌ BBC 錯誤：{url} - {e}")
        return None
