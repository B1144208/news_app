
import json
import os
import time
import random

from urllib.parse import urljoin
from selenium.webdriver.remote.webdriver import WebDriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from bs4 import BeautifulSoup

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from fake_useragent import UserAgent

from . import CLASSIFY_KEYWORD
from . import function_news
from newsCrawler import utils

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
AUTHOR_CLASSIFY_PATH = os.path.join(BASE_DIR, "AUTHOR_CLASSIFY.json")
AUTHOR_UNKNOWN_PATH  = os.path.join(BASE_DIR, "AUTHOR_UNKNOWN.json" )

def change_fake_ua(driver):

    driver.quit()

    # 初始化 Chrome 浏览器选项
    options = Options()
    
    # 使用 fake_useragent 生成随机的 User-Agent
    ua = UserAgent()
    user_agent = ua.random  # 随机生成一个 User-Agent
    
    # 设置随机的 User-Agent
    options.add_argument(f"user-agent={user_agent}")
    
    # 创建 WebDriver 实例
    driver = webdriver.Chrome(options=options)
    
    # 动态修改 User-Agent（可选）
    driver.execute_cdp_cmd('Network.setUserAgentOverride', {
        "userAgent": user_agent  # 使用刚才生成的随机 User-Agent
    })
    
    print("Driver initialized with User-Agent:", user_agent)
    return driver




# 宣告函式
""" 流程函式: start_channel_collection -> get_channel_information -> get_news_information """
def start_channel_collection(BASE_URL: str, SUB_TAG: str, driver: WebDriver) -> list[dict]:
    """ TODO: 擷取全部的 authors ( 專欄作者入口處 ) """
    ...
def get_channel_information(CHANNELS_URL: list[dict], driver: WebDriver) -> list[dict]:
    """ TODO: 擷取 NEWS_URL 的全部新聞資訊，並存成 JSON 格式的 list """
    ...

""" 功能函式 """
def load_author_json(file_path: str = AUTHOR_CLASSIFY_PATH) -> list[dict]:
    """ TODO: 載入 JSON 檔案 ( AUTHOR_CLASSIFY.json & AUTHOR_UNKNOWN.json ) """
    ...
def classify_author(name: str, job: str) -> tuple[str, bool]:
    """ TODO: 分辨 author 是 people / channel ，都不是回傳 unknown """
    """       str 包含 { people, channel, unknown}                """
    """       bool 表示是否在 AUTHOR_CLASSIFY.json 中              """
    ...
def save_author_data(authors: list[dict], classify_file: str="AUTHOR_CLASSIFY.json", unknown_file: str="AUTHOR_UNKNOWN.json"):
    """ TODO: 將非 AUTHOR_CLASSIFY.json 的 list 寫入 AUTHOR_CLASSIFY.json & AUTHOR_UNKNOWN.json 中 """
    ...
def AUTHOR_UNKNOWN_save_to_AUTHOR_CLASSIFY():
    """ TODO: 將 AUTHOR_UNKNOWN.json 中 tag 不為 unknown 的資料寫入 AUTHOR_CLASSIFY.json 中 """
    ...

# ==== 以下為實作細節 ====
# 擷取各作者連結 (新聞台擷取起點)
def start_channel_collection(BASE_URL: str, SUB_TAG: str, driver: WebDriver) -> list[dict]:

    FULL_URL = urljoin(BASE_URL, SUB_TAG)
    print("🚀 開始載入專欄作者：", FULL_URL)

    
    driver.get(FULL_URL)
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.CLASS_NAME, "pagiNum"))
    )
    soup = BeautifulSoup(driver.page_source, "html.parser")


    # 擷取總頁數
    page_info = soup.find("span", class_="pagiNum")
    if not page_info or "/" not in page_info.text:
        print("❌ : <FTV專欄作者> 無法取得總頁數")
        return []
    
    try:
        _, total_page = page_info.text.strip().split(":")
        _, total_page = map(int, total_page.strip().split("/"))
    except Exception as e:
        print("❌ : <FTV專欄作者> 總頁數解析錯誤")
    
    author_url_list = []
    not_in_json = []

    for page in range(1, total_page+1):
        page_url = urljoin(BASE_URL, f"{SUB_TAG}/{str(page)}")

        
        driver.get(page_url)
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.CLASS_NAME, "pagiNum"))
        )
        soup = BeautifulSoup(driver.page_source, "html.parser")

        # 擷取作者清單
        author_list = soup.find("div", class_="author-list")
        authors = author_list.find_all("li", class_="col-md-3 col-sm-4 col-6")
        # print(f"📄 第 {page} 頁，共 {total_page} 頁，找到 {len(authors)} 位作者")

        for author in authors:
            a_tag = author.find("a", class_="author")
            href = a_tag.get("href", "")
            href = urljoin(BASE_URL, href)  # fr"{BASE_URL}\{href}"
            name = a_tag.find("div", class_="name").get_text(strip=True)
            job = a_tag.find("div", class_="job").get_text(strip=True)

            tag, is_new = classify_author(name, job)

            # 加入 URL 回傳列表
            author_url_list.append({"href": href, "tag": tag})

            # 加入新資料到 not_in_json
            if is_new:
                not_in_json.append({"name": name, "tag": tag})

        time.sleep(random.uniform(2, 4))

    # 統一儲存新資料
    if not_in_json:
        save_author_data(not_in_json)
    
    #print(author_url_list)                # 網址格式有問題
    get_channel_information(BASE_URL, author_url_list, driver)

    return author_url_list

# 擷取 channel 資訊
def get_channel_information(BASE_URL: str, CHANNELS_URL: list[dict], driver: WebDriver) -> list[dict]:

    
    channels_data = utils.load_json("CHANNEL_DATA_bella.json")
    existing_urls = {item["url"] for item in channels_data if "url" in item}

    #driver = change_fake_ua(driver)
    channels = []
    for channel in CHANNELS_URL:
        
        

        news_url = []
        
        # 擷取 channel 資料
        channel_data = {}

        href = channel['href']
        tag = channel['tag']
        
        # 如果已經有該新聞，則跳過
        if href in existing_urls:
            continue

        
        driver.get(href)
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.CLASS_NAME, "pagiNum"))
        )
        soup = BeautifulSoup(driver.page_source, "html.parser")

        channel = soup.find("div", class_="author")
        img_block = channel.find("div", class_="img-block")
        img = img_block.find("img", {"loading": "lazy"})["src"]
        name = channel.find("h1", class_="name").text.strip()
        job = channel.find("div", class_="job").text.strip()
        introduce = channel.find("div", class_="intro").text.strip()

        if tag=='channel':
            channel_data['url'] = href
            channel_data['img'] = img
            channel_data['name'] = name
            channel_data['type'] = job
            channel_data['update_rate'] = None
            channel_data['introduce'] = introduce

            channels.append(channel_data)
            #print(f"channel_data:\n{channel_data}\n\n")
        else:
            name = "民視新聞網"
            continue
        
        
        time.sleep(random.uniform(1, 3))

        #print(f"channels:\n{channels}\n\n")

        
        
        utils.save_data_to_json(channels, output_file="CHANNEL_DATA_bella.json")
        
        
        
        """
        # 擷取總頁數
        page_info = soup.find("span", class_="pagiNum")
        if not page_info or "/" not in page_info.text:
            print(f"❌ : <FTV專欄作者> {name} 無法取得總頁數")
            return []
        
        try:
            _, total_page = page_info.text.strip().split(":")
            _, total_page = map(int, total_page.strip().split("/"))
        except Exception as e:
            print(f"❌ : <FTV專欄作者> {name} 總頁數解析錯誤")

        # 擷取新聞連結
        for page in range(1, total_page + 1):
            page_url = f"{href}/{str(page)}"

            WebDriverWait(driver, 10).until(
                EC.presence_of_element_located((By.CLASS_NAME, "pagiNum"))
            )
            soup = BeautifulSoup(driver.page_source, "html.parser")

            news_list = soup.find("section", class_="news-list mt-30")  # 尋找所有 <a> 標籤並獲取 href 屬性
            news_list = soup.find_all("li", class_="col-md-4 col-sm-6")

            # 取得每個 <a> 標籤的 href 屬性
            for news in news_list:
                a_tag = news.find("a", href=True)
                if(a_tag):
                    url = urljoin(BASE_URL, a_tag.get("href"))
                    news_url.append(url)

            time.sleep(random.uniform(2, 4))

        # print(f"news_url_list:\n[\n{news_url}\n]\n")
        function_news.get_news_information(news_url, driver, CHANNEL=name)
        """
    utils.save_data_to_json(channels, output_file="CHANNEL_DATA_bella.json")
    
    return channels

# 載入 json 檔案
def load_author_json(file_path: str = AUTHOR_CLASSIFY_PATH) -> list[dict]:
    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as f:
            try:
                return json.load(f)
            except json.JSONDecodeError:
                return []
    return []

# 判別關鍵字是人還是新聞台
def classify_author(name: str, job: str) -> tuple[str, bool]:
    job_text = f"{name}{job}"

    # 判斷 name 是否在 AUTHOR_CLASSIFY.json 中
    classify_data = load_author_json()
    for author in classify_data:
        if author.get("name") == name:
            return (author.get("tag", "unknown"), False)

    if any( keyword in job_text for keyword in CLASSIFY_KEYWORD.CHANNEL_KEYWORDS ):
        return ("channel", True)
    elif any( keyword in job_text for keyword in CLASSIFY_KEYWORD.PEOPLE_KEYWORDS ):
        return ("people", True)
    else:
        return ("unknown", True)
    
# 儲存 author 資料
def save_author_data(authors: list[dict], classify_file: str="AUTHOR_CLASSIFY.json", unknown_file: str="AUTHOR_UNKNOWN.json"):
    """
    儲存分類結果到 AUTHOR_CLASSIFY.json / AUTHOR_UNKNOWN.json。
    會自動排除重複項目。
    
    參數:
    - authors: List[dict]，每筆為 {"name": ..., "tag": ...}
    """
    
    classify_data = load_author_json()
    unknown_data  = load_author_json(AUTHOR_UNKNOWN_PATH)

    # 用 set 加速比對已存在資料（只比對 name）
    existing_classify = { item["name"] for item in classify_data }
    existing_unknown  = { item["name"] for item in unknown_data }

    new_classify = []
    new_unknown  = []

    for author in authors:
        name = author.get("name")
        tag = author.get("tag", "unknown")

        if not name:
            continue  # 跳過無效項目

        if tag == "unknown":
            if name not in existing_unknown:
                new_unknown.append({"name": name, "tag": tag})
        else:
            if name not in existing_classify:
                new_classify.append({"name": name, "tag": tag})

    # 寫入 AUTHOR_CLASSIFY 檔案
    if new_classify:
        classify_data.extend(new_classify)
        with open(AUTHOR_CLASSIFY_PATH, "w", encoding="utf-8") as f:
            json.dump(classify_data, f, ensure_ascii=False, indent=2)
        print(f"✅ 已儲存 {len(new_classify)} 筆作者分類資料到 {classify_file} 中")
    
    # 寫入 AUTHOR_UNKNOWN 檔案
    if new_unknown:
        unknown_data.extend(new_unknown)
        with open(AUTHOR_UNKNOWN_PATH, "w", encoding="utf-8") as f:
            json.dump(unknown_data, f, ensure_ascii=False, indent=2)
        print(f"✅ 已儲存 {len(new_unknown)} 筆作者分類資料到 {unknown_file} 中")
    
    print(f"✅ {classify_file} / {unknown_file} 寫入完成")

    return

#  將 AUTHOR_UNKNOWN.json 的資料，存入 AUTHOR_CLASSIFY 中
def AUTHOR_UNKNOWN_save_to_AUTHOR_CLASSIFY():
    classify_data = load_author_json()
    unknown_data = load_author_json(AUTHOR_UNKNOWN_PATH)

    new_classify = []
    new_unknown = []
    
    for element in unknown_data:
        if not element['tag']=='unknown':
            new_classify.append(element)
        else:
            new_unknown.append(element)

    # 寫入 AUTHOR_CLASSIFY 檔案
    if new_classify:
        classify_data.extend(new_classify)
        with open(AUTHOR_CLASSIFY_PATH, "w", encoding="utf-8") as f:
            json.dump(classify_data, f, ensure_ascii=False, indent=2)
        print(f"✅ 已新增 {len(new_classify)} 筆作者分類資料到 AUTHOR_CLASSIFY.json 中")
    
    # 寫入 AUTHOR_UNKNOWN 檔案
    with open(AUTHOR_UNKNOWN_PATH, "w", encoding="utf-8") as f:
        json.dump(new_unknown, f, ensure_ascii=False, indent=2)
    print(f"✅ 已儲存 {len(new_unknown)} 筆作者分類資料到 AUTHOR_UNKNOWN.json 中")
    
    print(f"✅ AUTHOR_UNKNOWN_save_to_AUTHOR_CLASSIFY 寫入完成")

    return