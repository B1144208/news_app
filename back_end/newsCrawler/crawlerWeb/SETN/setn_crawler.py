import requests
from bs4 import BeautifulSoup
import json

headers = {"User-Agent": "Mozilla/5.0"}

# Parser 區
def parse_detail(news_soup):
    """解析新聞內文與封面圖"""
    detail = []
    cover_img = None

    # 1️⃣ ckuse 結構
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
                        cover_img = {"src": img_src, "alt": img_alt}
                    detail.append({"img": {"src": img_src, "alt": img_alt}})
        return cover_img, detail

    # 2️⃣ printdiv 結構
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
                        cover_img = {"src": img_src, "alt": img_alt}
                    detail.append({"img": {"src": img_src, "alt": img_alt}})
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

def parse_channel(news_soup):
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


def parse_channel_list():
    """爬取 https://www.setn.com/ 的子頻道清單"""
    url = "https://www.setn.com/"
    res = requests.get(url, headers=headers)
    soup = BeautifulSoup(res.text, "html.parser")

    CHANNEL_DATA = []

    channel_items = soup.select("ul.channelarea-content li a")
    for item in channel_items:
        href = item.get("href")
        img_tag = item.find("img")
        img_src = (
            img_tag.get("data-src")
            or img_tag.get("srcset")
            or img_tag.get("src")
        )
        name = img_tag.get("alt", "").strip()

        channel_item = {
            "url": href,
            "img": img_src,
            "name": name,
            "type": None,
            "introduce": ""
        }
        CHANNEL_DATA.append(channel_item)

    return CHANNEL_DATA

# 主程式
def crawl_setn_hot():
    setn_url = "https://www.setn.com/viewall.aspx?pagegroupid=0"
    response = requests.get(setn_url, headers=headers)
    soup = BeautifulSoup(response.text, "html.parser")

    articles = soup.select("div.col-sm-12 a.gt")

    NEWS_DATA = []
    CHANNEL_DATA = []

    for article in articles[:20]:  # 只抓前 20 篇
        title = article.text.strip()
        link = "https://www.setn.com" + article["href"] if article["href"].startswith("/") else article["href"]

        news_res = requests.get(link, headers=headers)
        news_soup = BeautifulSoup(news_res.text, "html.parser")

        channel = "三立新聞網"

        publish_date = parse_publish_date(news_soup)
        cover_img, detail = parse_detail(news_soup)

        news_item = {
            "url": link,
            "channel": channel,
            "cover_img": cover_img,
            "title": title,
            "publish_date": publish_date,
            "detail": detail,
            "comment": [],
        }
        NEWS_DATA.append(news_item)

        channel_item = parse_channel(news_soup)
        if channel_item and channel_item not in CHANNEL_DATA:
            CHANNEL_DATA.append(channel_item)

    # 把首頁頻道清單也加進 CHANNEL_DATA
    homepage_channels = parse_channel_list()
    for c in homepage_channels:
        if c not in CHANNEL_DATA:
            CHANNEL_DATA.append(c)

    # 輸出 JSON
    with open("4_NEWS_trend.json", "w", encoding="utf-8") as f:
        json.dump(NEWS_DATA, f, ensure_ascii=False, indent=2)

    with open("4_CHANNEL_trend.json", "w", encoding="utf-8") as f:
        json.dump(CHANNEL_DATA, f, ensure_ascii=False, indent=2)

    print("✅ 爬取完成，已輸出 4_NEWS_trend.json 與 4_CHANNEL_trend.json")


if __name__ == "__main__":
    crawl_setn_hot()
