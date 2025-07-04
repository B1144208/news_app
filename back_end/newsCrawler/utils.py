import os
import json

from urllib.parse import urljoin
from selenium import webdriver                              # Selenium 的主要 API，用來啟動和操作瀏覽器
from selenium.webdriver.chrome.service import Service       # 設定 ChromeDriver 的啟動參數與路徑
from selenium.webdriver.chrome.options import Options       # 配置 Chrome 瀏覽器的啟動選項（例如無頭、路徑等）

from fake_useragent import UserAgent

ua = UserAgent()
headers = {
    'User-Agent': ua.random  # 随机 User-Agent
}



# 將抓到的html原始碼儲存
def save_html_source(html_txt, filename="a_temp.html"):
    with open(filename, "w", encoding="utf-8") as f:
        f.write(html_txt)
    print(f"✅ HTML 原始碼已儲存到 {filename}")

# 載入 json 檔案
def load_json(file_name: str, file_dir: str = os.path.join(os.path.dirname(os.path.abspath(__file__)))) -> list[dict]:
    file_path = urljoin(file_dir, file_name)
    print(file_path)
    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as f:
            try:
                return json.load(f)
            except json.JSONDecodeError:
                return []
    return []

# 將新聞資料儲存到 JSON
def save_data_to_json(articles: dict, output_file="output.json", path=os.path.join(os.path.dirname(os.path.abspath(__file__)))):
    """
    將單篇新聞資料附加儲存到 output.json 中。
    如果檔案不存在，會自動建立並寫入第一筆資料。
    """
    # 將完整路徑組合
    full_path = os.path.join(path, output_file)
    

    # 檢查資料夾是否存在，不存在就建立
    os.makedirs(path, exist_ok=True)

    if os.path.exists(full_path):
        with open(full_path, "r", encoding="utf-8") as f:
            try:
                data = json.load(f)
                if not isinstance(data, list):
                    data = []                   # 如果格式錯誤就重建
            except json.JSONDecodeError:
                data = []                       # 空檔案或格式錯誤
    else:
        data = []
    

    if isinstance(articles, list):              # 多筆資料
        data.extend(articles)
    else:                                       # 單筆資料
        data.append(articles)

    # 寫回 JSON
    with open(full_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"✅ 已新增 {len(articles)} 篇資料到 {output_file}（目前共 {len(data)} 篇新聞）")


def normalize_url(BASE_URL: str, href: str, allow_prefixes=["http", "https"]) -> str:
    """
    標準化網址：
    - 若 href 不是完整網址（不以 http/https 開頭），則加上 BASE_URL
    - 去除尾端斜線
    - 轉為小寫
    """
    if not any(href.startswith(prefix) for prefix in allow_prefixes):
        href = BASE_URL + href

    return href.rstrip("/").lower()


def get_chrome_paths(folder_chrome="chrome-win64", folder_driver="chromedriver-win64"):
    # 取得目前目錄的絕對路徑
    project_root = os.path.dirname(os.path.abspath(__file__))

    # 設定 Chrome 和 ChromeDriver 的路徑
    chrome_binary_path = os.path.join(project_root, folder_chrome, "chrome.exe")
    chromedriver_path = os.path.join(project_root, folder_driver, "chromedriver.exe")
    return chrome_binary_path, chromedriver_path


def init_steal_driver(USER_AGENT, headless=True):

    chrome_binary_path, chromedriver_path = get_chrome_paths()

    options = Options()
    options.binary_location = chrome_binary_path
    
    if headless:
        options.add_argument("--headless=new")
    options.add_argument("--log-level=3")       # 只顯示錯誤訊息
    options.add_argument("--disable-logging")   # 關掉日誌
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_argument(f"--user-agent={USER_AGENT}")
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    prefs = {
        "profile.default_content_setting_values.notifications": 2,
    }
    options.add_experimental_option("prefs", prefs)
    options.add_experimental_option("useAutomationExtension", False)

    service = Service(executable_path=chromedriver_path)
    driver = webdriver.Chrome(service=service, options=options)

    # 修正 JS 誤寫：navigate → navigator，underfined → undefined
    driver.execute_cdp_cmd("Page.addScriptToEvaluateOnNewDocument", {
        "source": """
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined
            })
        """
    })

    print("✅ Stealth Chrome 啟動成功")
    return driver
