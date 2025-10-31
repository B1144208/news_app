import os
import json
import requests
import inspect

from pathlib import Path
from dotenv import load_dotenv
from typing import Any, Dict, List, Iterable, Tuple, Optional, Union, Callable

from urllib.parse import urljoin
from selenium import webdriver                              # Selenium 的主要 API，用來啟動和操作瀏覽器
from selenium.webdriver.chrome.service import Service       # 設定 ChromeDriver 的啟動參數與路徑
from selenium.webdriver.chrome.options import Options       # 配置 Chrome 瀏覽器的啟動選項（例如無頭、路徑等）

from fake_useragent import UserAgent

# 隨機 user-agent
ua = UserAgent()
headers = {
    'User-Agent': ua.random  # 隨機 User-Agent
}


def get_chrome_paths(chrome_binary_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe", chromedriver_path=r"C:\tools\chromedriver.exe"):
    return chrome_binary_path, chromedriver_path

def init_steal_driver(USER_AGENT, headless=True):

    chrome_binary_path, chromedriver_path = get_chrome_paths()

    options = Options()
    options.binary_location = chrome_binary_path
    
    if headless:
        options.add_argument("--headless=new")
    options.add_argument("--log-level=3")       # 只顯示錯誤訊息
    options.add_argument("--disable-logging")   # 關掉日誌
    options.add_argument("--disable-gpu")       # 關閉 gpu
    options.add_argument("--no-sandbox")        # 關閉沙盒
    options.add_argument("--disable-software-rasterizer")   # 禁用軟體渲染
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

# 將抓到的html原始碼儲存
def save_html_source(html_txt, filename="a_temp.html"):
    with open(filename, "w", encoding="utf-8") as f:
        f.write(html_txt)
    print(f"✅ HTML 原始碼已儲存到 {filename}")

# 載入 json 檔案
def load_json(file_name: str, file_dir: str = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'newsCrawler', 'crawlerData')) -> list[dict]:
    file_path = urljoin(file_dir, file_name)
    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as f:
            try:
                return json.load(f)
            except json.JSONDecodeError:
                return []
    return []

def set_json(file_name: str, set_item: str, file_dir: str = os.path.join(os.path.dirname(os.path.abspath(__file__)))):
    file_path = urljoin(file_dir, file_name)
    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            set_data = { item[f"{set_item}"] for item in data }
        

# 判斷 compare_list 是否有在 absolute_list 中
def compare_list(compare_list, absolute_list) -> list:

    new_list = []
    for c_list in compare_list:
        if not c_list in absolute_list:
            new_list.append(c_list)
    return new_list

# 將新聞資料儲存到 JSON
def save_data_to_json( articles, path=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'newsCrawler', 'crawlerData' ), output_file="output.json", overwrite=False ):
    """
    將單篇新聞資料附加儲存到 output.json 中。
    如果檔案不存在，會自動建立並寫入第一筆資料。
    """
    # 將完整路徑組合
    full_path = os.path.join(path, output_file)
    
    # 檢查資料夾是否存在，不存在就建立
    os.makedirs(path, exist_ok=True)

    if not overwrite:
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
    else:
        data = articles

    # 寫回 JSON
    with open(full_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    if not overwrite:
        print(f"✅ 已新增 {len(articles)} 篇資料到 {output_file}（目前共 {len(data)} 篇資料）")


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

# 載入 .env
env_parent = Path(__file__).resolve().parent.parent
load_dotenv( dotenv_path = env_parent / ".env")
BASE_URL = os.getenv( "REMOTE_API" )

# api
def call_news_api( data: Optional[List] = None, channel_id: Optional[str] = None ) -> bool:
    # input: data or channel_id
    # data: list
    # channel_id: json

    if not data and not channel_id:
        return False
    
    try:
        # API URL
        url = BASE_URL + "/api/news/batch"

        # 取得資料
        crawlerData = []
        if data:
            crawlerData = data 
        else:
            file_name = channel_id + "_" + os.getenv("CRAWLER_NEWS_FILE")
            file_path = Path(env_parent / os.getenv("CRAWLER_DATA_PATH") / file_name)
            
            # 可選 Header（如需 Token）
            """headers = {
                "Authorization": "Bearer YOUR_TOKEN_HERE",
                "Content-Type": "application/json"
            }"""
        
            try:
                with file_path.open("r", encoding="utf-8") as f:
                    crawlerData = json.load(f)
            except json.JSONDecodeError:
                # 壞檔或空檔時，避免崩潰
                crawlerData = []
            except Exception as e:
                raise RuntimeError(f"讀取 {file_name} 失敗: {e}")

        fake_req = {
            "data": crawlerData
        }

        try: 
            # 發出 POST 請求
            response = requests.post(url, json=fake_req)
            
            # 解析返回
            if response.status_code == 200:
                result = response.json()
            else:
                print("❌ 請求失敗，HTTP code：", response.status_code, response.text)

            # 清空 json 資料
            if channel_id:
                try :
                    with file_path.open("w", encoding="utf-8") as f:
                        json.dump( [], f, ensure_ascii=False )
                except Exception as e:
                    print("❌ 請求過程中發生錯誤:", str(e))
                    return False
        except Exception as e:
            print("❌ 請求過程中發生錯誤:", str(e))
            return False
    except Exception as e:
        print("❌ 請求過程中發生錯誤:", str(e))
        return False
    return True 

def call_channel_api( data: Optional[List] = None, channel_id: Optional[str] = None ):
    # input: data or channel_id
    # data: list
    # channel_id: json

    if not data and not channel_id:
        return False
    
    # API URL
    url = BASE_URL + "/api/channel/batch"
    crawlerData = []
    if data:
        crawlerData = data 
    else:
        file_name = channel_id + "_" + os.getenv("CRAWLER_CHANNEL_FILE")
        file_path = Path(env_parent / os.getenv("CRAWLER_DATA_PATH") / file_name)
        
        # 可選 Header（如需 Token）
        """headers = {
            "Authorization": "Bearer YOUR_TOKEN_HERE",
            "Content-Type": "application/json"
        }"""
    
        try:
            with file_path.open("r", encoding="utf-8") as f:
                crawlerData = json.load(f)
        except json.JSONDecodeError:
            crawlerData = []
        except Exception as e:
            raise RuntimeError(f"讀取 {file_name} 失敗: {e}")

    fake_req = {
        "data": crawlerData
    }

    try: 
        # 發出 POST 請求
        response = requests.post(url, json=fake_req)
        
        # 解析返回
        if response.status_code == 200:
            result = response.json()
        else:
            print("❌ 請求失敗，HTTP code：", response.status_code, response.text)

        # 清空 json 資料
        if channel_id:
            try :
                with file_path.open("w", encoding="utf-8") as f:
                    json.dump( [], f, ensure_ascii=False )
            except Exception as e:
                print("❌ 請求過程中發生錯誤:", str(e))
    except Exception as e:
        print("❌ 請求過程中發生錯誤:", str(e))

def errorlog( action: str, param1: Any = None, param2: Any = None, file_path:Optional[Path] = None, file_name="__errorlog__.json"):

    if not file_path:
        # 使用 inspect 來獲取當前函式的調用堆疊
        frame = inspect.currentframe()  # 獲取當前堆疊的框架
        caller_frame = frame.f_back  # 獲取上層函式的框架
        caller_file = caller_frame.f_code.co_filename  # 獲取調用者的檔案路徑
        file_path = Path(caller_file).parent
    full_path = file_path / file_name
    full_path.parent.mkdir(parents=True, exist_ok=True)

    # 讀檔（容錯：檔案不存在或壞掉就重建）
    errlog_obj: Dict[str, Any]
    if full_path.exists():
        try:
            with full_path.open("r", encoding="utf-8") as f:
                errlog_obj = json.load(f)
        except Exception:
            errlog_obj = {"fn": [], "data": {}}
    else:
        errlog_obj = {"fn": [], "data": {}}

    # 資料型別保守校正
    if not isinstance(errlog_obj.get("fn"), list):
        errlog_obj["fn"] = []
    if not isinstance(errlog_obj.get("data"), dict):
        errlog_obj["data"] = {}

    fn: List[Any] = errlog_obj["fn"]
    data: Dict[str, Any] = errlog_obj["data"]

    # 再修改
    # set_data, set_many_data, pop_list, delete_data, push_fn, pop_fn
    act = action.replace("-", "_").lower()

    if act == "set_data":
        key = param1
        value = param2
        if not isinstance(key, str):
            raise TypeError("set_data 需要 param1 為字串 key")
        data[key] = value
        
    elif act=="set_many_data":
        payload = param1
        if isinstance(payload, dict):
            data.update(payload)
        elif isinstance(payload, Iterable):
            for item in payload:
                if not (isinstance(item, (list, tuple)) and len(item) == 2 and isinstance(item[0], str)):
                    raise TypeError("set_many_data 需要 Iterable[Tuple[str, Any]] 或 Dict[str, Any]")
                k, v = item
                data[k] = v
        else:
            raise TypeError("set_many_data 需要 Dict[str, Any] 或 Iterable[Tuple[str, Any]]")
    
    elif act=="pop_list":
        key = param1
        if not isinstance(key, str):
            raise TypeError("pop_list 需要 param1 為字串 key")
        data[key].pop(0)
        if len(data[key])==0:
            del data[param1]

    elif act=="delete_data":
        try:
            del data[param1]
        except Exception as e:
            return

    elif act=="push_fn":
        fn_name = param1.__name__ if callable(param1) else str(param1)

        # param2: list[dict]，逐一 set 到 data
        if param2:
            if not isinstance(param2, list) or not all(isinstance(d, dict) for d in param2):
                raise TypeError("push_fn 的 param2 需為 list[dict]")
            for d in param2:
                for k, v in d.items():
                    data[k] = v
        fn.append(fn_name)
        
    elif act=="pop_fn":
        if fn:
            fn.pop()
    else:
        raise ValueError(f"未知的 action: {action}")
    
    # 回寫檔案
    obj = {"fn": fn, "data": data}
    with full_path.open("w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)

    return

if __name__=="__main__":
    call_news_api( channel_id=1)
