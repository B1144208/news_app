import re
import os
import json
import time
import random

from typing import Optional, List, Dict
from urllib.parse import urljoin
from selenium.webdriver.remote.webdriver import WebDriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.chrome.options import Options


from newsCrawler import utils
from newsCrawler.utils import errorlog
from . import function_channel
from newsCrawler.object import CrawlerData, CrawlerQueue, ErrorLog

# 定義函式
"""
流程函式: start_news_collection -> extract_news_urls -> get_news_information
""" 
def start_news_collection(BASE_URL: str, crawlerData, newsQueue, driver) -> List[Dict]:
    """ TODO: 擷取 BASE_URL 的全部 ( SUB_URL, GROUP ) 傳給 extract_news_urls() """
    ...
def extract_news_urls(BASE_URL: str, SUB_URL: List[Dict], crawlerData, newsQueue, driver, breakPage) -> None:
    """ TODO: 擷取 SUB_URL 的全部 NEWS_URL 傳給 get_news_information() """
    ...
def get_news_information(NEWS_URLS: List[str], crawlerData, newsQueue, driver, GROUP: str, CHANNEL: str) -> List[Dict]:
    """ TODO: 擷取 NEWS_URL 的全部新聞資訊，並存成 JSON 格式的 list """
    ...

# ==== 實作細節 ====
# 擷取各分類連結 (新聞擷取起點)
def start_news_collection(BASE_URL: str, crawlerData, newsQueue, driver):

    # push-fn
    errorlog("push-fn", start_news_collection, [
        {"BASE_URL": BASE_URL}
    ])

    print("🚀 開始載入首頁：", BASE_URL)
    driver.get(BASE_URL)
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.ID, "menuNav"))
    )

    # 使用 BeautifulSoup 擷取 HTML
    soup = BeautifulSoup(driver.page_source, "html.parser")

    # 擷取分類連結
    menu_nav = soup.find("div", id="menuNav")
    menu_items = menu_nav.select("ul.MenuList a") if menu_nav else []
    
    previous_pref = None

    try :
        SUB_URL = []
        
        for li in menu_items:
            href = li.get("href")
            group = li.get_text(strip=True)

            if not href:
                continue    # 忽略 href 為空

            # 標準化網址
            href = utils.normalize_url(BASE_URL, href)
            
            if(href==previous_pref):
                continue
            previous_pref = href


            article = {
                "url": href,
                "group": group
            }
            SUB_URL.append(article)

        # push SUB_URL
        errorlog("set-data", "SUB_URL", SUB_URL)

    except Exception as e:
        return
    
    # pop-fn
    errorlog("pop-fn")

    extract_news_urls(BASE_URL, SUB_URL, crawlerData, newsQueue, driver)
    return

# 擷取分類之新聞連結
def extract_news_urls(BASE_URL: str, SUB_URL: List[Dict], crawlerData, newsQueue, driver, breakPage = 1):
    
    print(f"extract_news_urls: breakPage:{breakPage}")
    # push-fn
    errorlog("push-fn", extract_news_urls, [
        {"BASE_URL" : BASE_URL  },
        {"SUB_URL"  : SUB_URL   },
        {"breakPage": breakPage }
    ])

    for suburl_item in SUB_URL:
        url = suburl_item["url"]
        group = suburl_item["group"]

        # 略過特殊網頁
        if "author" in url:
            errorlog("pop-list", "SUB_URL")
            continue
        if group in ["首頁", "即時", "熱門", "體育", "財經", "長照", "英語新聞", "數位專題"]:
            errorlog("pop-list", "SUB_URL")
            continue
        if group in ["即時"]:
            errorlog("pop-list", "SUB_URL")
            continue

        driver.get(url)
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.CLASS_NAME, "news-block"))
        )
        soup = BeautifulSoup(driver.page_source, "html.parser")

        print(f"開始擷取{group}分類:", BASE_URL)

        # 擷取總頁數
        page_info = soup.find("span", class_="pagiNum")
        if not page_info or "/" not in page_info.text:
            print(f"❌ : <{group}分類> 無法取得總頁數")
            return []
        try:
            _, total_page = page_info.text.strip().split(":")
            _, total_page = map(int, total_page.strip().split("/"))
        except Exception as e:
            print(f"❌ : <{group}分類> 總頁數解析錯誤")


        for page in range(breakPage, total_page + 1):

            # 啟動 driver
            page_url = f"{url}/{str(page)}"
            driver.get(page_url)
            WebDriverWait(driver, 10).until(
                EC.presence_of_element_located((By.CLASS_NAME, "pagiNum"))
            )
            soup = BeautifulSoup(driver.page_source, "html.parser")
            # 擷取新聞連結
            news_urls = []
            news_block = soup.find_all("div", class_="news-block")
            for block in news_block:
                href = block.find("a", class_ = "img-block").get("href")
                if not href:
                    continue

                # 標準化網址
                href = utils.normalize_url(BASE_URL, href)
                news_urls.append(href)

            # update errLog data: breakPage
            errorlog("set-data", "breakPage", breakPage + 1)

            # update errLog data: SUB_URL, breakPage
            if page==total_page:
                errorlog("delete-data", "breakPage")
                errorlog("pop-list", "SUB_URL")

            if news_urls:
                get_news_information(news_urls, crawlerData, newsQueue, driver, GROUP=group)

            time.sleep(random.uniform(2, 4))
            print(f"✅: 擷取完成 {group}分類 : 第 {page} 頁")
        
        print(f"<{group}類別> 新聞擷取完成")
        
        
    
    # pop-fn
    errorlog("pop-fn")

    return

# 擷取新聞完整資訊
def get_news_information(NEWS_URLS: List[str], crawlerData, newsQueue, driver, GROUP: Optional[str] = None, CHANNEL: Optional[str] = None) -> List[Dict]:

    # push-fn
    errorlog("push-fn", get_news_information, [
        {"NEWS_URLS": NEWS_URLS },
        {"GROUP"    : GROUP     },
        {"CHANNEL"  : CHANNEL   }
    ])

    for url in NEWS_URLS:

        article = {}
        driver.get(url)
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.CLASS_NAME, "text-center"))
        )
        soup = BeautifulSoup(driver.page_source, "html.parser")

        # 存取新聞原始連結 (用來判斷是否已經有該新聞)
        article["url"] = url

        # 存取新聞分類 ( 可 None )
        article["group"] = GROUP if GROUP else None
        
        # 擷取新聞台資訊
        if not CHANNEL:
            # 如果有 channel 資訊
            channel_name = "民視新聞網"  # 預設值為 "民視新聞網"
            channel = soup.find("div", class_="author-detail")
            if channel:
                channel_name = channel.find("div", class_="name").text
                channel_job = channel.find("div", class_="job").text

                # 使用 classify_author 來判斷 tag
                tag, _ = function_channel.classify_author(channel_name, channel_job)
                if tag=="people":
                    channel_name = "民視新聞網"
    
            article["channel"] = channel_name
        else:
            article["channel"] = CHANNEL

        # 圖片(封面)
        try:
            cover_img = driver.find_element(By.CSS_SELECTOR, "#View_Img img")
            cover_img_src = cover_img.get_attribute("src")
            # 嘗試抓取 alt 屬性，若找不到則設為 None
            try:
                cover_img_alt = driver.find_element(By.CSS_SELECTOR, "#View_Img figcaption").text
            except Exception as e:
                cover_img_alt = None
            
            article["cover_img"] = {
                "src": cover_img_src,
                "alt": cover_img_alt
            }
        except Exception as e:
            article["cover_img"] = None
            print("❌ 封面圖片擷取失敗：", e)

        # 標題
        news_title = soup.find("h1", class_="text-center border-0").get_text(strip=True)
        article["title"] = news_title

        # 發布時間
        publish_date = soup.find("span", class_="date").get_text(strip=True)
        publish_date = publish_date.split("：")[1]
        article["publish_date"] = publish_date
        
        # 內文( text + img )
        detail = []
        
        # 抓取 preface 區塊
        preface = soup.find("div", id="preface")
        p_tags = preface.find_all("p")
        if p_tags:
            for p in p_tags:
                content_html = str(p)
                # 如果包含 <br> ，就拆開
                if "<br" in content_html:
                    segments = re.split(r"<\s*br\s*/\s*>", p.decode_contents(), flags = re.IGNORECASE)
                    for seg in segments:
                        clean_text = BeautifulSoup(seg, "html.parser").get_text(strip=True)
                        if clean_text:
                            detail.append({"text": clean_text})
                # 如果不包含 <br> ，整段處理
                else:
                    text = p.get_text(strip=True)
                    if text:
                        detail.append({"text": text})

        # 新聞內文 (text + img)
        content = soup.find("div", id="newscontent")
        for element in content.find_all(["p", "figure"]):
            if element.name=="p":
                content_html = str(element)
                # 如果包含 <br> ，就拆開
                if "<br" in content_html:
                    segments = re.split(r"<\s*br\s*/\s*>", element.decode_contents(), flags = re.IGNORECASE)
                    for seg in segments:
                        clean_text = BeautifulSoup(seg, "html.parser").get_text(strip=True)
                        if clean_text:
                            detail.append({"text": clean_text})
                # 如果不包含 <br> ，整段處理
                else:
                    text = element.get_text(strip=True)
                    if text:
                        detail.append({"text": text})

            elif element.name=="figure" and "fr-img-wrap" in element.get('class', []):
                img_tag = element.find('img')
                if img_tag and img_tag.get('src'):
                    # 如果有圖片，則獲取圖片的 src
                    img_src = img_tag['src']
                    
                    # 查找圖片說明 <figcaption>
                    figcaption = element.find('figcaption')
                    caption_text = figcaption.get_text(strip=True) if figcaption else None
                    
                    # 將圖片的 src 和說明一起儲存
                    detail.append({
                        "img": {
                            'src':img_src, 
                            'alt': caption_text
                        }
                    })
        article["detail"] = detail
        
        # 關鍵字
        keyword = []
        news_tag = soup.find("div", class_="news-tag")
        if news_tag:
            news_tag = news_tag.find_all("li")
            for ky in news_tag:
                key = ky.find("a").text.strip()
                keyword.append(key)
            # 去除重複與空值
            keyword = list(set(keyword))
        
        if len(keyword)==0:
            keyword = None
        article["keyword"] = keyword

        # 評論
        article["comment"] = None

        # push Queue
        newsQueue.push_one(article)

        # update errLog data: NEWS_URLS
        errorlog("pop-list", "NEWS_URLS")

    # pop-fn
    errorlog("pop-fn")

    return

