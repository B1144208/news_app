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
from fake_useragent import UserAgent
import requests # 引入 requests 庫來識別 HTTP 錯誤

from newsCrawler.object import CrawlerData, CrawlerQueue
from newsCrawler import utils

# ===================================================
# USA Today 爬蟲配置
# ===================================================
BASE_URL = "https://www.usatoday.com"
CHANNEL_ID = "3"
CRAWLER_NAME = "USA Today"

# ---------------------------------------------------
# 輔助函式 (可能需要 utils.py 提供 init_steal_driver)
# ---------------------------------------------------

def get_new_driver():
    """ 封裝 WebDriver 初始化邏輯，方便重啟 """
    user_agent = UserAgent().random
    # 假設 utils.init_steal_driver 存在
    return utils.init_steal_driver(user_agent, headless=True)

def _is_valid_article(article: Dict, url: str) -> bool:
    """ 嚴格驗證：確保所有欄位存在且內容有效 (已針對伺服器要求優化) """

    # 必須檢查的欄位列表
    required_fields = ["url", "title", "channel", "publish_date", "detail", "group", "location", "cover_img", "keyword"]
    for field in required_fields:
        if field not in article:
            print(f"⚠️ 資料結構錯誤：{url} - 缺少關鍵欄位 '{field}'。")
            return False

    # 1. 檢查標題
    if not article["title"] or article["title"] == "無標位符":
        print(f"⚠️ 資料驗證失敗：{url} - 標題缺失或為佔位符。")
        return False

    # 2. 檢查內文 (必須包含有效文本，如果為空，驗證失敗)
    if not article["detail"] or not isinstance(article["detail"], list):
        print(f"⚠️ 資料驗證失敗：{url} - 內文格式錯誤或為空。")
        return False

    # 確保內文列表中至少有一個非空的文本元素 (避免只擷取到空段落)
    has_valid_text = any(item.get("text", "").strip() for item in article["detail"])
    if not has_valid_text:
        print(f"⚠️ 資料驗證失敗：{url} - 內文擷取失敗或缺失有效內容。")
        return False

    # 3. 檢查時間 (確保長度足夠且格式正確，伺服器要求 ISO 格式，包含 T 或 Z)
    if not article["publish_date"] or len(article["publish_date"]) < 10 or 'T' not in article["publish_date"]:
        print(f"⚠️ 資料驗證失敗：{url} - 發布時間格式無效 (非 ISO 8601)。")
        return False

    return True


# ---------------------------------------------------
# 主要運行函式 (run)
# ---------------------------------------------------
def run(crawlerData: CrawlerData):
    driver = get_new_driver()
    newsQueue = CrawlerQueue(
        name=CRAWLER_NAME,
        kind="news",
        crawler_data=crawlerData,
        interval_sec=300,
        progress_every=10
    )

    history_urls = set()
    backup_file_path = crawlerData.path / crawlerData.news

    # 🌟 修正點 1.1：載入已寫入 JSON 檔案的歷史資料 🌟
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

    # 🌟 修正點 1.2：載入目前仍在佇列快照中（尚未成功寫入）的 URL 🌟
    for item in newsQueue.snapshot():
        if isinstance(item, dict) and 'url' in item:
            history_urls.add(item['url'])

    print(f"[{CRAWLER_NAME}] 載入 {len(history_urls)} 筆歷史 URL 進行去重。")

    try:
        # 🌟 修正點 2.1：傳遞 history_urls 🌟
        start_news_collection(BASE_URL, crawlerData, newsQueue, driver, history_urls)

    except Exception as e:
        print(f"❌ {CRAWLER_NAME} 爬蟲發生嚴重錯誤: {e}")
        if newsQueue:
            print(f"[{CRAWLER_NAME}] 異常退出！強制儲存已成功抓取的資料...")
            newsQueue.backup_drain()
        raise

    finally:
        if driver:
            driver.quit()
        newsQueue.stop_autobackup()
        print(f"✅ {CRAWLER_NAME} 爬蟲執行結束，所有資源已釋放。")

# ----------------------------------------------------------------------
# 宣告函式 (get_channel_info)
# ----------------------------------------------------------------------
def get_channel_info():
    """ 提供爬蟲頻道的基本資訊 """
    return {
        "name": CRAWLER_NAME,
        "url": BASE_URL
    }

# ----------------------------------------------------------------------
# ==== 流程實作細節 (start_news_collection & extract_news_urls) ====
# ----------------------------------------------------------------------
def start_news_collection(BASE_URL: str, crawlerData: CrawlerData, newsQueue: CrawlerQueue, driver: WebDriver, history_urls: set):

    utils.errorlog("push-fn", start_news_collection, [
        {"BASE_URL": BASE_URL}
    ])

    SUB_URL = [{
        "url": BASE_URL,
        "group": "USA Today 首頁"
    }]

    print(f"🚀 {CRAWLER_NAME} 開始載入新聞入口：", BASE_URL)

    # 🌟 修正點 2.2：傳遞 history_urls 🌟
    extract_news_urls(BASE_URL, SUB_URL, crawlerData, newsQueue, driver, history_urls)

    utils.errorlog("pop-fn")
    return

def extract_news_urls(BASE_URL: str, SUB_URL: List[Dict], crawlerData: CrawlerData, newsQueue: CrawlerQueue, driver: WebDriver, history_urls: set, limit: int = 150):

    utils.errorlog("push-fn", extract_news_urls, [
        {"BASE_URL": BASE_URL},
        {"SUB_URL": SUB_URL},
        {"limit": limit}
    ])

    suburl_item = SUB_URL[0]
    url = suburl_item["url"]
    group = suburl_item["group"]

    driver.get(url)

    for _ in range(3):
        driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        time.sleep(random.uniform(1.5, 3.0))

    try:
        WebDriverWait(driver, 15).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "a[href*='/story/']"))
        )
    except Exception:
        print(f"⚠️ {CRAWLER_NAME} 首頁未偵測到新聞連結，可能是網站結構變動或載入失敗。")
        utils.errorlog("pop-fn")
        return

    soup = BeautifulSoup(driver.page_source, "html.parser")

    print(f"開始擷取 {group} 分類連結:", url)

    news_urls = []
    selectors = [
        "h2 a[href*='/story/']",
        "h3 a[href*='/story/']",
        "a[href*='/story/']",
    ]

    seen_links = set()
    for selector in selectors:
        for link in soup.select(selector):
            href = link.get("href")
            if not href: continue

            full_url = utils.normalize_url(BASE_URL, href)

            if any(keyword in full_url for keyword in ['/site-services/', '/elections/', '/opinion/', '#', '?']):
                continue

            # 🌟 修正點 3：在收集階段進行去重檢查 🌟
            if full_url in history_urls or full_url in seen_links:
                continue

            seen_links.add(full_url)

            news_urls.append({
                "url": full_url,
                "title": link.get_text(strip=True).strip(),
            })

            if len(news_urls) >= limit: break

        if len(news_urls) >= limit: break

    if news_urls:
        print(f"✅ 找到 {len(news_urls)} 則新聞連結，準備擷取內容...")
        # 🌟 修正點 4：傳遞 history_urls 給下一階段 🌟
        get_news_information(news_urls, crawlerData, newsQueue, driver, history_urls, GROUP=group, CHANNEL=CRAWLER_NAME)
    else:
        print(f"⚠️ {group} 分類未找到有效新聞連結。")

    utils.errorlog("pop-fn")
    return

# ----------------------------------------------------------------------
# ==== 新聞內容擷取實作 ( get_news_information ) 最終版本 ====
# ----------------------------------------------------------------------

# 🌟 修正點 5：函式簽名加入 history_urls 🌟
def get_news_information(NEWS_URLS: List[Dict], crawlerData: CrawlerData, newsQueue: CrawlerQueue, driver: WebDriver, history_urls: set, GROUP: Optional[str] = None, CHANNEL: Optional[str] = None) -> List[Dict]:

    utils.errorlog("push-fn", get_news_information, [
        {"NEWS_URLS": NEWS_URLS},
        {"GROUP": GROUP},
        {"CHANNEL": CHANNEL}
    ])

    for url_item in NEWS_URLS:
        url = url_item['url']
        article = {}
        print(f"📥 正在擷取新聞: {url}")

        soup = None
        detail = []
        is_session_error = False # 追蹤是否為 WebDriver 錯誤

        try:
            # 嘗試使用 driver 進行操作
            driver.get(url)
            # 等待新聞標題 (H1) 元素出現
            WebDriverWait(driver, 15).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "h1.gnt_ar_hl"))
            )

            soup = BeautifulSoup(driver.page_source, "html.parser")

            # -----------------------------------------------------
            # 資料擷取與強制初始化 (確保所有欄位存在)
            # -----------------------------------------------------

            article["url"] = url
            article["group"] = GROUP if GROUP else ""
            article["channel"] = CHANNEL if CHANNEL else CRAWLER_NAME
            article["location"] = ""

            # 標題
            title_tag = soup.select_one("h1.gnt_ar_hl")
            article["title"] = title_tag.get_text(strip=True) if title_tag else "無標題"

            # 封面圖片
            cover_tag = soup.select_one("figure img")
            article["cover_img"] = {
                "src": utils.normalize_url(BASE_URL, cover_tag.get("src", "")) if cover_tag else "",
                "alt": cover_tag.get("alt", "") if cover_tag else ""
            }
            if not article["cover_img"]["src"]:
                 article["cover_img"] = {"src": "", "alt": ""}

            # 發布時間 (關鍵修正區域)
            time_tag = soup.select_one("time[datetime]")

            # 設置一個預設的 ISO 8601 時間，以防擷取失敗，這是伺服器要求的格式
            publish_date = datetime.now().isoformat(timespec='seconds').replace('+00:00', 'Z')

            if time_tag and time_tag.has_attr("datetime"):
                try:
                    # 解析時間字串，並處理時區偏移
                    dt_obj = datetime.fromisoformat(time_tag["datetime"].replace('Z', '+00:00'))

                    # 🚀 最終修正：轉換為嚴格的 ISO 8601 格式 (YYYY-MM-DDTHH:MM:SSZ)
                    publish_date = dt_obj.isoformat(timespec='seconds').replace('+00:00', 'Z')

                except ValueError:
                    # 如果 HTML 中的時間格式無法解析，則使用當前預設值
                    pass

            article["publish_date"] = publish_date

            # 內文 (text + img)
            for p in soup.select("div.gnt_ar_b p.gnt_ar_b_p"):
                text = p.get_text(strip=True)
                if text:
                    detail.append({
                        "text": text,
                        "img": {"src": "", "alt": ""}
                    })

            # 內文賦值 (不使用佔位符，如果為空則讓驗證失敗)
            article["detail"] = detail

            # 確保 keyword 是 List[str]
            article["keyword"] = []

            # -----------------------------------------------------
            # 推入佇列前的嚴格資料驗證
            # -----------------------------------------------------

            if _is_valid_article(article, url):
                # 只有資料通過嚴格驗證，才推入佇列
                newsQueue.push_one(article)

                # 🌟 修正點 6：將新爬取的 URL 加入 history_urls 🌟
                history_urls.add(url)
            else:
                # 驗證失敗的資料被丟棄
                pass

        # 捕捉所有的擷取錯誤 (包括 WebDriver 和 requests 錯誤)
        except Exception as e:
            error_message = str(e)

            # 檢查並重啟 WebDriver
            if "invalid session id" in error_message or "WebDriver is not connected" in error_message:
                print(f"🚨 偵測到 WebDriver 會話失效！正在嘗試重啟 driver...")
                try:
                    driver.quit()
                except:
                    pass
                # 由於 driver 變數在函式內部是區域性的，這裡重啟只影響本函式內部的變數
                # 更好的做法是將 driver 作為全域變數處理或通過 return/yield 模式處理，
                # 但為保持結構不變，先這樣處理。
                driver = get_new_driver()
                print("✅ Driver 重啟成功。本次 URL 失敗，將在下一輪嘗試新 URL。")
                is_session_error = True # 標記為會話錯誤，跳過 sleep

            elif "Read timed out" in error_message or "HTTPConnectionPool" in error_message:
                print(f"🚨 API 傳輸超時或連接錯誤！本次 URL 推送失敗。錯誤原因: {error_message.splitlines()[0]}")

            else:
                # 內容擷取或未知錯誤
                print(f"❌ {CRAWLER_NAME} 新聞內容擷取錯誤：{url} - {e}")


        # 關鍵：不論成功、失敗或驗證失敗，都將該 URL 從待處理列表中移除
        utils.errorlog("pop-list", "NEWS_URLS")

        # 修正：只有在非 WebDriver 重啟時才執行 sleep
        if not is_session_error:
            time.sleep(random.uniform(1, 3))

    utils.errorlog("pop-fn")
    return