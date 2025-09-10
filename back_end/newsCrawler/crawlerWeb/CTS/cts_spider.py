import requests
from bs4 import BeautifulSoup
from datetime import datetime

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                  "AppleWebKit/537.36 (KHTML, like Gecko) "
                  "Chrome/120.0.0.0 Safari/537.36"
}
BASE_URL = "https://news.cts.com.tw"


def get_channel_info():
    return {
        "name": "CTS",
        "url": BASE_URL
    }


def fetch_news_list(limit=5):
    try:
        res = requests.get(BASE_URL, headers=HEADERS)
        res.encoding = "utf-8"
        res.raise_for_status()
    except Exception as e:
        print(f"[CTS] 首頁請求錯誤: {e}")
        return []

    soup = BeautifulSoup(res.text, "html.parser")
    items = soup.select(".news-slideshow.item")

    news_list = []
    for item in items[:limit]:
        link_el = item.select_one("a")
        img_el = item.select_one(".news-slide-img img")
        title_el = item.select_one(".slide-title")

        if not (link_el and title_el):
            continue

        link = link_el["href"]
        title = title_el.get_text(strip=True)
        image = img_el["src"] if img_el else ""

        full_link = link if link.startswith("http") else BASE_URL + link

        detail, publish_date = fetch_news_detail(full_link)

        news = {
            "url": full_link,
            "group": "",
            "channel": "CTS",
            "cover_img": {"src": image, "alt": ""},
            "title": title,
            "publish_date": publish_date or datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "location": "",
            "detail": detail,
            "keyword": [""]  # 暫時無關鍵字
        }
        news_list.append(news)

    return news_list


def fetch_news_detail(url):
    try:
        res = requests.get(url, headers=HEADERS)
        res.encoding = "utf-8"
        res.raise_for_status()
    except Exception as e:
        print(f"[CTS] 無法取得內容 {url}：{e}")
        return [], None

    soup = BeautifulSoup(res.text, "html.parser")

    content_els = soup.select(".artical-content p")
    detail = []
    for p in content_els:
        text = p.get_text(strip=True)
        if text:
            detail.append({"text": text, "img": {"src": "", "alt": ""}})

    # 發布時間
    time_el = soup.select_one("time.artical-time")
    publish_date = None
    if time_el and time_el.has_attr("datetime"):
        publish_date = time_el["datetime"]

    return detail, publish_date
