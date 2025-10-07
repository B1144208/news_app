import requests
from bs4 import BeautifulSoup
import json
from datetime import datetime

BASE_URL = "https://www.npr.org"
NEWS_SECTION_URL = "https://www.npr.org/sections/news/"

def get_news_list():
    res = requests.get(NEWS_SECTION_URL, headers={"User-Agent": "Mozilla/5.0"})
    res.raise_for_status()
    soup = BeautifulSoup(res.text, "html.parser")

    news_items = []

    articles = soup.select("article")
    for art in articles:
        link_tag = art.select_one("h2 a")
        if not link_tag:
            continue
        url = link_tag["href"]
        title = link_tag.get_text(strip=True)

        # cover image
        img_tag = art.select_one("img")
        cover_img = {}
        if img_tag:
            cover_img = {
                "src": img_tag.get("src"),
                "alt": img_tag.get("alt")
            }

        # publish date
        date_tag = art.select_one("time")
        publish_date = None
        if date_tag and date_tag.has_attr("datetime"):
            try:
                dt = datetime.fromisoformat(date_tag["datetime"].replace("Z", "+00:00"))
                publish_date = dt.strftime("%Y/%m/%d %H:%M:%S")
            except:
                publish_date = date_tag.get_text(strip=True)

        detail = get_news_detail(url)

        news_items.append({
            "url": url,
            "channel": "NPR News",
            "cover_img": cover_img if cover_img else None,
            "title": title,
            "publish_date": publish_date,
            "detail": detail,
            "comment": []
        })

    return news_items


def get_news_detail(url):
    res = requests.get(url, headers={"User-Agent": "Mozilla/5.0"})
    res.raise_for_status()
    soup = BeautifulSoup(res.text, "html.parser")

    details = []
    body = soup.select("div[data-metrics-container='StoryText'] p, div[data-metrics-container='StoryText'] img")

    for elem in body:
        if elem.name == "p":
            text = elem.get_text(strip=True)
            if text:
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
    return details


def get_channel_data():
    return [{
        "url": NEWS_SECTION_URL,
        "img": "https://media.npr.org/include/images/facebook-default-wide.jpg",  # NPR generic image
        "name": "NPR News",
        "type": None,
        "introduce": "Latest national and world news from NPR."
    }]


def main():
    news_data = get_news_list()
    channel_data = get_channel_data()

    with open("NEWS_DATA.json", "w", encoding="utf-8") as f:
        json.dump(news_data, f, ensure_ascii=False, indent=2)

    with open("CHANNEL_DATA.json", "w", encoding="utf-8") as f:
        json.dump(channel_data, f, ensure_ascii=False, indent=2)

    print("輸出完成：NEWS_DATA.json, CHANNEL_DATA.json")


if __name__ == "__main__":
    main()
