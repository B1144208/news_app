import asyncio
from playwright.async_api import async_playwright
import json
#from datetime import datetime
import os

# 輸出資料夾
os.makedirs("news/國際", exist_ok=True)

async def scrape_nhk():
    url = "https://www3.nhk.or.jp/news/cat06.html"

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            args=["--disable-http2"]
        )
        page = await browser.new_page()
        await page.goto(url, wait_until="domcontentloaded", timeout=60000)

        await page.wait_for_selector("div.content--items ul.content--list dd a")

        articles = await page.query_selector_all("div.content--items ul.content--list dd a")
        news_data = []
        channel_data = []

        for article in articles:
            title_tag = await article.query_selector("em.title")
            if not title_tag:
                continue

            news_title = (await title_tag.inner_text()).strip()
            link = await article.get_attribute("href")
            if not link:
                continue
            if link.startswith("/"):
                link = "https://www3.nhk.or.jp" + link

            # 打開新聞內頁
            detail_page = await browser.new_page()
            await detail_page.goto(link)
            await detail_page.wait_for_selector("article")

            # 發布時間
            try:
                publish_date = await detail_page.inner_text("time")
            except:
                publish_date = None

            # 內文
            paragraphs = await detail_page.query_selector_all("article p")
            detail_content = []
            for p_tag in paragraphs:
                text = (await p_tag.inner_text()).strip()
                if text:
                    detail_content.append({"text": text})

            # 封面圖
            try:
                img_tag = await detail_page.query_selector("article img")
                if img_tag:
                    img_src = await img_tag.get_attribute("src")
                    img_alt = await img_tag.get_attribute("alt")
                    cover_img = {"src": img_src, "alt": img_alt if img_alt else ""}
                else:
                    cover_img = {}
            except:
                cover_img = {}

            # 關鍵字
            keywords = []
            try:
                keyword_tags = await detail_page.query_selector_all("meta[name='keywords']")
                for kw in keyword_tags:
                    kw_content = await kw.get_attribute("content")
                    if kw_content:
                        keywords.extend([k.strip() for k in kw_content.split(",") if k.strip()])
            except:
                pass

            news_data.append({
                "url": link,
                "group": "國際新聞",
                "channel": "NHK新聞",
                "cover_img": cover_img,
                "news_title": news_title,
                "publish_date": publish_date,
                "location": None,
                "detail": detail_content,
                "keyword": keywords
            })

            # 作者/頻道資訊
            channel_data.append({
                "url": link,
                "img": cover_img.get("src", ""),
                "name": "NHK新聞",
                "type": "新聞媒體",
                "update_rate": None,
                "introduce": ""
            })

            await detail_page.close()

        await browser.close()

    # 輸出 JSON
    with open("news/國際/NEWS_DATA.json", "w", encoding="utf-8") as f:
        json.dump(news_data, f, ensure_ascii=False, indent=2)

    with open("news/國際/CHANNEL_DATA.json", "w", encoding="utf-8") as f:
        json.dump(channel_data, f, ensure_ascii=False, indent=2)

    print("爬取完成，已輸出 NEWS_DATA.json 和 CHANNEL_DATA.json！")


if __name__ == "__main__":
    asyncio.run(scrape_nhk())