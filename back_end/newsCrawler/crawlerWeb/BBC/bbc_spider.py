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
from datetime import datetime

# 假設 newsCrawler.object, newsCrawler.utils 存在
from newsCrawler.object import CrawlerData, CrawlerQueue
from newsCrawler import utils
from selenium import webdriver
from fake_useragent import UserAgent

# BBC 的基礎 URL
CRAWLER_NAME ="BBC"
BASE_URL = "https://www.bbc.com"

def run(crawlerData: CrawlerData):
        """
        BBC 爬蟲的啟動函式。
        """
        # 1. 初始化 WebDriver (使用 utils.init_steal_driver)
        user_agent = UserAgent().random
        driver = utils.init_steal_driver(user_agent)

        # 2. 初始化 Queue
        newsQueue = CrawlerQueue(
            name="BBC",
            kind="news",
            crawler_data=crawlerData,
            interval_sec=300,        # 每 5 分鐘自動備份/上傳
            progress_every=10        # 每 10 筆資料呼叫 API
        )

        # 2.1 🌟 修正點：從 JSON 檔案和佇列快照載入所有歷史 URL 進行去重 🌟
        history_urls = set()
        backup_file_path = crawlerData.path / crawlerData.news

        # 載入已成功寫入 JSON 檔案的歷史資料
        if backup_file_path.exists():
            try:
                with backup_file_path.open('r', encoding='utf-8') as f:
                    backup_data = json.load(f)
                    if isinstance(backup_data, list):
                        for item in backup_data:
                            if isinstance(item, dict) and 'url' in item and item.get('channel') == CRAWLER_NAME:
                                history_urls.add(item['url'])
            except (json.JSONDecodeError, IOError) as e:
                print(f"[{CRAWLER_NAME}] 載入歷史 URL 檔案錯誤: {e}. 將從空集合開始。")

        # 載入目前仍在佇列快照中（等待備份或 API 推送）的 URL
        for item in newsQueue.snapshot():
            if isinstance(item, dict) and 'url' in item:
                history_urls.add(item['url'])

        print(f"[{CRAWLER_NAME}] 載入 {len(history_urls)} 筆歷史 URL 進行去重。")

        # 3. 執行主爬蟲邏輯
        try:
            BASE_URL = "https://www.bbc.com"
            # 🌟 修正點：傳遞 history_urls 🌟
            start_news_collection(BASE_URL, crawlerData, newsQueue, driver, history_urls)

        except Exception as e:
            print(f"❌ BBC 爬蟲發生嚴重錯誤: {e}")
            # 在錯誤發生時，強制備份佇列中的剩餘資料
            newsQueue._graceful_backup()

        finally:
            # 4. 關閉 WebDriver 和停止自動備份
            driver.quit()
            newsQueue.stop_autobackup()
            print("✅ BBC 爬蟲執行結束，所有資源已釋放。")

# ----------------------------------------------------------------------
# 宣告函式 (更新簽名)
# ----------------------------------------------------------------------

def get_channel_info():
    """ 提供爬蟲頻道的基本資訊 """
    return {
        "name": "BBC",
        "url": BASE_URL + "/news"
    }

"""
流程函式: start_news_collection -> extract_news_urls -> get_news_information
"""
def start_news_collection(BASE_URL: str, crawlerData: CrawlerData, newsQueue: CrawlerQueue, driver: WebDriver, history_urls: set):
    """ 擷取 BASE_URL 的全部 ( SUB_URL, GROUP ) 傳給 extract_news_urls() """
    ...
def extract_news_urls(BASE_URL: str, SUB_URL: List[Dict], crawlerData: CrawlerData, newsQueue: CrawlerQueue, driver: WebDriver, history_urls: set, breakPage: int = 1):
    """ 擷取 SUB_URL 的全部 NEWS_URL 傳給 get_news_information() """
    ...
def get_news_information(NEWS_URLS: List[str], crawlerData: CrawlerData, newsQueue: CrawlerQueue, driver: WebDriver, history_urls: set, GROUP: Optional[str] = None, CHANNEL: Optional[str] = None) -> List[Dict]:
    """ 擷取 NEWS_URL 的全部新聞資訊，並存入佇列 """
    ...

# ----------------------------------------------------------------------
# ==== 以下為實作細節 ====
# ----------------------------------------------------------------------

# 擷取各分類連結 (新聞擷取起點)
def start_news_collection(BASE_URL: str, crawlerData: CrawlerData, newsQueue: CrawlerQueue, driver: WebDriver, history_urls: set):
    """ 擷取 BASE_URL 的全部 ( SUB_URL, GROUP ) 傳給 extract_news_urls() """

    # 您的日誌紀錄 (使用 utils.errorlog)
    utils.errorlog("push-fn", start_news_collection, [
        {"BASE_URL": BASE_URL}
    ])

    NEWS_HOME_URL = utils.normalize_url(BASE_URL, "/news")

    # BBC 結構簡單，我們將 BBC News 首頁視為一個主要分類
    SUB_URL = [{
        "url": NEWS_HOME_URL,
        "group": "BBC News 首頁精選"
    }]

    utils.errorlog("set-data", "SUB_URL", SUB_URL)
    print("🚀 BBC 開始載入新聞入口：", NEWS_HOME_URL)

    # 🌟 修正點：傳遞 history_urls 🌟
    extract_news_urls(BASE_URL, SUB_URL, crawlerData, newsQueue, driver, history_urls)

    utils.errorlog("pop-fn")
    return

# 擷取分類之新聞連結
def extract_news_urls(BASE_URL: str, SUB_URL: List[Dict], crawlerData: CrawlerData, newsQueue: CrawlerQueue, driver: WebDriver, history_urls: set, breakPage: int = 1):
    """ 擷取 SUB_URL 的全部 NEWS_URL 傳給 get_news_information() """

    # breakPage 參數對於 BBC News 主頁可能不適用，因為它通常是單頁無限捲動或加載。
    # 這裡沿用您的結構，但只處理 SUB_URL 中的第一頁。
    utils.errorlog("push-fn", extract_news_urls, [
        {"BASE_URL": BASE_URL},
        {"SUB_URL": SUB_URL},
        {"breakPage": breakPage}
    ])

    for suburl_item in SUB_URL:
        url = suburl_item["url"]
        group = suburl_item["group"]

        driver.get(url)
        # 等待新聞連結元素出現 (使用您的原始選擇器)
        WebDriverWait(driver, 15).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "a[href*='/news/articles/']"))
        )
        soup = BeautifulSoup(driver.page_source, "html.parser")

        print(f"開始擷取 {group} 分類連結:", url)

        news_urls = []
        seen_links = set()

        # 擷取新聞連結 (沿用您的原始選擇器)
        for link in soup.select("a[href*='/news/articles/']"):
            href = link.get("href")
            if not href or href in seen_links:
                continue

            full_url = utils.normalize_url(BASE_URL, href)

            # 🌟 修正點：檢查是否已存在於歷史紀錄中 🌟
            if full_url in history_urls:
                continue

            seen_links.add(href)
            news_urls.append(full_url)


        if news_urls:
            print(f"✅ 找到 {len(news_urls)} 則新聞連結，準備擷取內容...")
            # 🌟 修正點：傳遞 history_urls 🌟
            get_news_information(news_urls, crawlerData, newsQueue, driver, history_urls, GROUP=group, CHANNEL="BBC")
        else:
            print(f"⚠️ {group} 分類未找到有效新聞連結。")

        # 由於只處理一頁，我們假裝該 SUB_URL 處理完畢
        utils.errorlog("pop-list", "SUB_URL")
        time.sleep(random.uniform(2, 4))

    utils.errorlog("pop-fn")
    return

# 擷取新聞完整資訊
def get_news_information(NEWS_URLS: List[str], crawlerData: CrawlerData, newsQueue: CrawlerQueue, driver: WebDriver, history_urls: set, GROUP: Optional[str] = None, CHANNEL: Optional[str] = None) -> List[Dict]:
    """ 擷取 NEWS_URL 的全部新聞資訊，並存入佇列 """

    utils.errorlog("push-fn", get_news_information, [
        {"NEWS_URLS": NEWS_URLS},
        {"GROUP": GROUP},
        {"CHANNEL": CHANNEL}
    ])

    for url in NEWS_URLS:
        article = {}
        print(f"📥 正在擷取新聞: {url}")

        try:
            driver.get(url)
            # 等待新聞標題 (H1) 元素出現
            WebDriverWait(driver, 15).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "h1"))
            )
            soup = BeautifulSoup(driver.page_source, "html.parser")

            article["url"] = url
            article["group"] = GROUP if GROUP else ""
            article["channel"] = CHANNEL if CHANNEL else "BBC"
            article["location"] = "" # 您的原始程式碼中的欄位

            # 標題 (沿用您的原始選擇器)
            title_tag = soup.select_one("h1")
            article["title"] = title_tag.get_text(strip=True) if title_tag else "無標題"

            # 封面圖片 (沿用您的原始選擇器)
            cover_tag = soup.select_one("img")
            article["cover_img"] = {
                "src": utils.normalize_url(BASE_URL, cover_tag.get("src", "")) if cover_tag else "",
                "alt": cover_tag.get("alt", "") if cover_tag else ""
            }

            # 發布時間 (沿用您的原始選擇器)
            time_tag = soup.select_one("time")
            publish_date = ""
            if time_tag and time_tag.has_attr("datetime"):
                publish_date = time_tag["datetime"]
            else:
                # 您的原始程式碼的 fallback
                publish_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            article["publish_date"] = publish_date

            # 內文 (text + img)
            detail = []
            # 您的原始程式碼：抓取 <article> 內的所有 <p>
            for p in soup.select("article p"):
                text = p.get_text(strip=True)
                if text:
                    # 模擬您專案的 detail 格式
                    detail.append({
                        "text": text,
                        "img": {"src": "", "alt": ""}
                    })

            article["detail"] = detail

            # 關鍵字
            article["keyword"] = [""] # 您的原始程式碼中的欄位 (暫時沒抓關鍵字)

            # 將結果推入佇列，並由 Queue 的背景執行緒儲存到 JSON 或呼叫 API
            newsQueue.push_one(article)

            # 🌟 修正點：將新爬取的 URL 加入 history_urls 🌟
            history_urls.add(url)

        except Exception as e:
            print(f"❌ BBC 新聞內容擷取錯誤：{url} - {e}")

        # 更新日誌堆疊
        utils.errorlog("pop-list", "NEWS_URLS")
        time.sleep(random.uniform(1, 3))

    utils.errorlog("pop-fn")
    return