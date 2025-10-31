import requests
from bs4 import BeautifulSoup
import json
import re
from urllib.parse import urlparse, parse_qs, urljoin, urlunparse, urlencode
import os
from pathlib import Path
import time
import sys
import traceback

# 匯入 Selenium 相關模組
from selenium import webdriver
from selenium.webdriver.chrome.service import Service as ChromeService
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium.common.exceptions import WebDriverException, TimeoutException

# 定義基礎 URL
BASE_MOBILE01_URL = "https://www.mobile01.com/"
# 定義批次寫入的大小
BATCH_SIZE = 10
# 定義每個版面爬取的最大頁數
MAX_PAGES_PER_FORUM = 5
# *** 最終修正：根據提供的 HTML 結構，使用實際的子版面名稱 ***
PRIMARY_TARGET_FORUM = "時事綜合討論區"

# 處理路徑：將輸出路徑定義為單一檔案
BASE_DIR = Path(__file__).resolve().parent.parent.parent
OUTPUT_FILE_PATH = BASE_DIR / "crawlerData" / "3_topic.json"
# 確保父目錄 (crawlerData) 存在
OUTPUT_FILE_PATH.parent.mkdir(parents=True, exist_ok=True)

print(f"✅ 輸出路徑已設定為: {OUTPUT_FILE_PATH}")
print(f"✅ 每個版面最大爬取頁數已設定為: {MAX_PAGES_PER_FORUM}")
print(f"🎯 優先抓取版面已設定為: {PRIMARY_TARGET_FORUM}")
print("🎯 模式：先抓取優先版面，再抓取所有其他版面。")

# =========================================================================
# Selenium 相關函數 (不變動)
# =========================================================================

def initialize_driver():
    """初始化並返回一個配置好的 Chrome WebDriver 實例。"""
    try:
        # 配置 Chrome 選項
        options = ChromeOptions()
        options.add_argument("--headless") # 無頭模式 (不顯示瀏覽器介面)
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        # 使用一個最新的 User-Agent
        options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36")

        # 關鍵：反偵測設置
        options.add_experimental_option("excludeSwitches", ["enable-automation"])
        options.add_experimental_option('useAutomationExtension', False)

        # 初始化驅動程式 (webdriver_manager 自動下載驅動)
        print("🔧 正在初始化 Chrome 驅動程式...")
        service = ChromeService(ChromeDriverManager().install())
        driver = webdriver.Chrome(service=service, options=options)
        driver.set_page_load_timeout(30) # 設置頁面載入超時
        return driver
    except Exception as e:
        print(f"❌ 無法初始化瀏覽器驅動，請檢查您是否已安裝 Chrome 瀏覽器: {e}")
        return None

def fetch_url_selenium(driver, url: str) -> str | None:
    """使用 Selenium 獲取網頁內容並等待 JavaScript 執行。 (等待時間 5 秒)"""
    try:
        driver.get(url)
        time.sleep(5)
        return driver.page_source
    except TimeoutException:
        print(f"❌ [Selenium] 載入超時: {url}")
        return None
    except WebDriverException as e:
        print(f"❌ [Selenium] WebDriver 執行錯誤: {url} ({e})")
        return None
    except Exception as e:
        print(f"❌ [Selenium] 未知錯誤: {url} ({e})")
        return None

def get_topic_id(url: str) -> str:
    """從帖子 URL 中提取 tid (帖子 ID)"""
    query_params = parse_qs(urlparse(url).query)
    return query_params.get('t', ['unknown'])[0]

# =========================================================================
# 階段三: 帖子深度爬蟲 (不變動)
# =========================================================================

def scrape_topic_detail(driver, url: str) -> dict | None:
    """爬取 Mobile01 單一帖子，提取主帖內容和所有回覆/留言，返回 tid, data 和 discuss 字段。"""

    tid = get_topic_id(url)

    html_content = fetch_url_selenium(driver, url)
    if not html_content:
        return None

    soup = BeautifulSoup(html_content, 'html.parser')

    result = {"tid": tid, "data": "", "discuss": []}

    # --- 1. 提取主帖內容 (data) ---
    title_tag = soup.find('meta', property='og:title')
    title = title_tag['content'].replace(' - Mobile01', '').strip() if title_tag else "Title Not Found"

    author_tag = soup.find('meta', property='dable:author')
    first_author_info = soup.find('div', class_='l-articlePage')
    author = "Author Not Found"
    if first_author_info:
        author_link = first_author_info.find('div', class_='l-author').find('a', class_='u-ellipsis') if first_author_info.find('div', class_='l-author') else None
        author = author_link.get_text(strip=True) if author_link else author_tag['content'] if author_tag else author

    time_tag = soup.find('meta', property='article:published_time')
    time_str = time_tag['content'].split('+')[0].replace('T', ' ') if time_tag else "Time Not Found"

    main_content_article = soup.find('div', class_='l-articlePage').find('article', id=lambda x: x and x.startswith('article_'))

    main_content = "Content Not Found"
    if main_content_article:
        for blockquote in main_content_article.find_all('blockquote'):
            blockquote.extract()
        main_content = main_content_article.get_text(separator=' ', strip=True)

    if main_content == "Content Not Found" or len(main_content) < 50:
        desc_tag = soup.find('meta', property='og:description')
        if desc_tag:
            main_content = re.sub(r'\(.*\s第1頁\)$', '...', desc_tag['content']).strip()

    result['data'] = f"標題: {title}\n作者: {author}\n發布時間: {time_str}\n內容: {main_content}"

    # --- 2. 提取回覆和留言 (discuss) ---
    article_containers = soup.find_all('div', class_='l-articlePage')

    for article_container in article_containers[1:]:
        author_info = article_container.find('div', class_='l-author')
        author_link = author_info.find('a', class_='u-ellipsis') if author_info else None
        reply_author = author_link.get_text(strip=True) if author_link else "Unknown Author"

        navigation = article_container.find('div', class_='l-navigation__item')
        time_span = navigation.find('span', class_='o-fNotes') if navigation else None
        reply_time = time_span.get_text(strip=True) if time_span else "Time Not Found"

        reply_content_tag = article_container.find('article', class_='c-articleLimit')

        reply_content = "Content Not Found"
        if reply_content_tag:
            for blockquote in reply_content_tag.find_all('blockquote'):
                blockquote.extract()
            reply_content = reply_content_tag.get_text(separator=' ', strip=True)

        result['discuss'].append(f"{reply_author} (回覆): {reply_time}: {reply_content}")

        message_list = article_container.find_all('div', class_='l-leaveMsg')
        for msg_item in message_list:
            msg_author_tag = msg_item.find('a', class_='u-username')
            msg_author = msg_author_tag.get_text(strip=True) if msg_author_tag else "Unknown Comment Author"

            navigation_item = msg_item.find('div', class_='l-navigation__item')
            if navigation_item:
                msg_time_tag = navigation_item.find('span', class_='o-fNotes')
            else:
                msg_time_tag = None

            msg_time = msg_time_tag.get_text(strip=True) if msg_time_tag else "Time Not Found"

            msg_content_tag = msg_item.find('div', class_='msgContent')
            msg_content = msg_content_tag.get_text(separator=' ', strip=True) if msg_content_tag else "Comment Content Not Found"

            result['discuss'].append(f"{msg_author} (留言): {msg_time}: {msg_content}")

    return result


# =========================================================================
# 階段一: 列表爬蟲 - 獲取論壇目錄 (不變動)
# =========================================================================

def get_forum_links(driver) -> list:
    """從 Mobile01 首頁獲取所有主要的論壇版面連結。"""
    print(f"--- 階段一: 爬取論壇目錄 ({BASE_MOBILE01_URL}) ---")

    html_content = fetch_url_selenium(driver, BASE_MOBILE01_URL)
    if not html_content:
        return []

    soup = BeautifulSoup(html_content, 'html.parser')

    forum_links = []
    # 選擇所有包含 forumtopic.php 或 topiclist.php 的連結，這涵蓋了所有級別的論壇版面。
    # 這也會抓到「時事綜合討論區」
    sub_links = soup.select('.l-menu a[href*="forumtopic.php"], .l-menu a[href*="topiclist.php"]')

    # 過濾掉那些僅僅是分類名稱，而非實際帖子列表的版面
    invalid_names = {
        '其他作業系統', '台灣品牌', '歐洲車系', '亞洲品牌', '歐美品牌', '日本車系', '英國車系',
        '德國車系', '法國車系', '瑞典車系', '義大利車系', '美國車系', '韓國車系', '台灣車系',
        '蘋果軟體綜合', 'Feature Phone', '資費與週邊', '汽車周邊', '汽車話題', '輕型與重型機車',
        '大型重型機車', '電動機車', '機車行車記錄器', '機車GPS', '可換鏡頭相機', '消費型相機',
        '運動、空拍、攝影機', '核心組件', '儲存裝置', '顯示設備', '電腦週邊', '機殼散熱',
        '網路產品', '電腦軟體',
        '時事' # 由於「時事」是一級分類連結，但 URL 與子版面相同，為保險起見，將其排除，只保留子版面。
    }

    for link in sub_links:
        forum_name = link.get_text(strip=True)
        forum_url = urljoin(BASE_MOBILE01_URL, link.get('href'))

        # 確保名稱長度大於 2 且不在無效名稱集合中
        is_valid_forum_name = len(forum_name) > 2 and forum_name not in invalid_names

        # 確保連結沒有重複
        if forum_url and is_valid_forum_name and forum_url not in [f['url'] for f in forum_links]:
            forum_links.append({
                "forum_name": forum_name,
                "url": forum_url
            })

    if not forum_links:
        print("未找到任何論壇版面連結。")
        return []

    print(f"總共找到 {len(forum_links)} 個有效論壇版面連結。")
    return forum_links

# =========================================================================
# 階段二: 列表爬蟲 - 獲取單一版面的帖子 URL (不變動)
# =========================================================================

def get_topic_links_from_single_forum(driver, forum: dict, max_pages: int) -> list:
    """從單一論壇版面爬取指定頁數的帖子 URL 列表。"""

    all_topic_urls = []
    base_url = forum['url']
    current_page = 1
    MAX_PAGES = max_pages

    parsed_url = urlparse(base_url)

    while current_page <= MAX_PAGES:
        # 1. 構建當前頁面的 URL (分頁參數 p=X)
        if current_page == 1:
            page_url = base_url
        else:
            query = parse_qs(parsed_url.query)
            query['p'] = [str(current_page)]
            new_query_string = urlencode(query, doseq=True)
            page_url = urlunparse(parsed_url._replace(query=new_query_string))

        print(f"   > 正在爬取第 {current_page} 頁: {page_url}")

        # 2. 獲取版面列表內容
        forum_html = fetch_url_selenium(driver, page_url)
        if not forum_html:
            print(f"   [警告] 第 {current_page} 頁內容獲取失敗或超時，跳過後續頁面。")
            break

        forum_soup = BeautifulSoup(forum_html, 'html.parser')
        # 找到頁面上所有帖子連結
        link_tags = forum_soup.select('a[href*="topicdetail.php"]')

        forum_topics_on_page = []
        for link_tag in link_tags:
            topic_url = urljoin(BASE_MOBILE01_URL, link_tag.get('href'))

            title_element = link_tag.find('div', class_='c-list__title')
            topic_title = title_element.get_text(strip=True) if title_element else link_tag.get_text(strip=True)
            topic_title = topic_title.strip().replace('\n', ' ').replace('\r', ' ')

            # 過濾無效標題
            is_valid_title = len(topic_title) > 3 and \
                             not topic_title.isdigit() and \
                             topic_title.lower() not in ['最新文章', '回覆', '點擊', '下一頁']

            if topic_url and is_valid_title:
                if topic_url not in [t['url'] for t in forum_topics_on_page]:
                     forum_topics_on_page.append({
                        "title": topic_title,
                        "url": topic_url
                    })

        if forum_topics_on_page:
            print(f"   > 第 {current_page} 頁抓取到 {len(forum_topics_on_page)} 個帖子。")
            all_topic_urls.extend(forum_topics_on_page)
            current_page += 1
            time.sleep(1)
        else:
            print(f"   > 第 {current_page} 頁未找到新的帖子連結，假設已達該版面最後一頁。")
            break

    if current_page > MAX_PAGES:
        print(f"   [警告] 達到 {MAX_PAGES} 頁的爬取上限，停止此版面分頁。")

    print(f"版面 {forum['forum_name']} 列表 URL 抓取完成。總共找到 {len(all_topic_urls)} 個帖子連結。")
    return all_topic_urls

# =========================================================================
# 輔助函式：載入/儲存數據 (不變動)
# =========================================================================

def load_or_init_data():
    """載入現有的 JSON 數據，如果檔案不存在則返回空列表。"""
    if OUTPUT_FILE_PATH.exists() and os.path.getsize(OUTPUT_FILE_PATH) > 0:
        try:
            with open(OUTPUT_FILE_PATH, 'r', encoding='utf-8') as f:
                return json.load(f)
        except json.JSONDecodeError:
            print("⚠️ 現有 3_topic.json 檔案損壞，將從頭開始創建新列表。")
            return []
    return []

def save_batch_data(data_list):
    """將累積的數據列表寫入/覆蓋到 3_topic.json 檔案。"""
    try:
        with open(OUTPUT_FILE_PATH, 'w', encoding='utf-8') as f:
            json.dump(data_list, f, ensure_ascii=False, indent=4)
        print(f"⭐ 批次寫入成功！目前已儲存 {len(data_list)} 篇帖子至: {OUTPUT_FILE_PATH.name}")
    except Exception as e:
        print(f"❌ 寫入 {OUTPUT_FILE_PATH.name} 失敗: {e}")

# =========================================================================
# 主執行入口 (使用修正後的 PRIMARY_TARGET_FORUM="時事綜合討論區")
# =========================================================================

def run(crawlerData=None):
    """Mobile01 爬蟲的主執行函式，優先處理「時事綜合討論區」版面，然後處理所有其他版面。"""

    driver = initialize_driver()
    if not driver:
        return

    # 載入現有數據
    all_topics_data = load_or_init_data()
    existing_tids = {d['tid'] for d in all_topics_data if 'tid' in d}

    total_newly_crawled_count = 0
    batch_counter = 0

    try:
        # 1. 獲取所有論壇版面連結
        all_forum_links = get_forum_links(driver)

        # 2. 區分優先目標和剩餘版面，確保目標版面在最前面
        primary_forum = None
        remaining_forums = []

        for forum in all_forum_links:
            if forum['forum_name'] == PRIMARY_TARGET_FORUM:
                primary_forum = forum
            else:
                remaining_forums.append(forum)

        # 組裝處理順序： [時事綜合討論區] + [其他版面]
        forums_to_process = []

        if primary_forum:
            forums_to_process.append(primary_forum)
            print(f"✅ 優先目標版面 '{PRIMARY_TARGET_FORUM}' 已加入處理隊列首位。")
            # 只有當找到了優先版面時，才將剩餘版面接在後面
            forums_to_process.extend(remaining_forums)
        else:
            # 如果還是找不到，則按原順序處理，並發出警告
            forums_to_process.extend(all_forum_links)
            print(f"❌ 警告：未在所有版面中找到指定的優先目標版面 '{PRIMARY_TARGET_FORUM}'，將按原順序處理。")


        # 3. 迭代處理所有論壇版面
        if forums_to_process:
            print(f"\n--- 開始迭代 {len(forums_to_process)} 個論壇版面進行深度爬取 ---")

            for i, forum in enumerate(forums_to_process):
                # 提示當前處理的版面順序和名稱
                print(f"\n==== 處理版面 {i+1}/{len(forums_to_process)}: {forum['forum_name']} ====")
                if forum['forum_name'] == PRIMARY_TARGET_FORUM:
                    print(f"*** 這是優先處理的 {PRIMARY_TARGET_FORUM} 版面 ***")

                # 3a. 獲取單一版面的帖子 URL 列表
                topic_links_for_forum = get_topic_links_from_single_forum(
                    driver,
                    forum,
                    max_pages=MAX_PAGES_PER_FORUM
                )

                if not topic_links_for_forum:
                    print(f"   [警告] 版面 {forum['forum_name']} 未抓取到任何帖子，跳過深度爬取。")
                    continue

                print(f"--- 階段三: 深度爬取版面 {forum['forum_name']} 中的 {len(topic_links_for_forum)} 篇帖子 ---")

                # 3b. 深度爬取該版面所有帖子
                for j, link in enumerate(topic_links_for_forum):

                    tid = get_topic_id(link['url'])
                    if tid in existing_tids:
                        continue

                    sleep_time = 1 + (j % 3) * 0.5
                    time.sleep(sleep_time)

                    topic_data = scrape_topic_detail(driver, link['url'])

                    if topic_data:
                        topic_data['list_title'] = link['title']

                        all_topics_data.append(topic_data)
                        existing_tids.add(tid)
                        total_newly_crawled_count += 1
                        batch_counter += 1

                        # 3c. 達到批次大小，立即寫入
                        if batch_counter >= BATCH_SIZE:
                            save_batch_data(all_topics_data)
                            batch_counter = 0

                # 3d. 在版面處理結束時，寫入剩餘的數據
                if batch_counter > 0:
                    print(f"版面 {forum['forum_name']} 處理完畢，正在儲存該版面剩餘的 {batch_counter} 筆數據...")
                    save_batch_data(all_topics_data)
                    batch_counter = 0

            # 4. 最終總結
            print(f"\n所有版面處理完畢。總共新增 {total_newly_crawled_count} 篇帖子。")
        else:
            print("沒有找到論壇版面連結，跳過深度爬取。")

    finally:
        if driver:
             driver.quit()
             print("⚙️ Chrome WebDriver 已關閉。")
        else:
             print("❌ 由於驅動程式初始化失敗，未能關閉 WebDriver。")

if __name__ == '__main__':
    run()