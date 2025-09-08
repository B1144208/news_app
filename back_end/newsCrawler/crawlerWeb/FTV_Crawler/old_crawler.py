from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from bs4 import BeautifulSoup
import time
import os
import json


FTV_Main_url = "https://www.ftvnews.com.tw/"

def news_crawler(url, type):

    # 設定 Chrome 執行選項
    options = Options()
    options.add_argument("--disable-gpu")
    options.add_argument("window-size=1920x1080")

    # 設定 ChromeDriver 路徑
    driver_path = os.path.join(os.path.dirname(__file__), '..', 'chromedriver.exe')
    service = Service(executable_path=driver_path)

    # 啟動瀏覽器
    driver = webdriver.Chrome(service=service, options=options)
    driver.get(url)

    # 等待網頁加載完成
    WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.ID, "View_Img")))
    # time.sleep(2)
    
    # 抓 HTML 原始碼
    html = driver.page_source
    soup = BeautifulSoup(html, "html.parser")

    
    data = []

    # 標題、作者、發布時間
    NewsTitle = soup.find("h1", class_="text-center border-0").get_text(strip=True)
    preface = soup.find("div", id="preface")
    p_tags = preface.find_all("p")
    NewsAuthor = p_tags[0].get_text(strip=True)
    PublishDate = soup.find("span", class_="date").get_text(strip=True)
    PublishDate = PublishDate.split("：")[1]
    print("NewsTitle   : ", NewsTitle)
    print("NewsAuthor  : ", NewsAuthor)
    print("PublishDate : ", PublishDate, '\n')

    # 圖片(封面)
    CoverImg = soup.find("figure", id="View_Img", class_="article-cover")
    img_src = CoverImg.find("img")
    img_src = img_src.get('src') if img_src else None
    print("CoverImg    : ", img_src)
    img_fig = CoverImg.find("figcaption") if img_src else None
    print("Caption     : ", img_fig.text, '\n')

    # 內文( text + img )
    element = p_tags[1].get_text(strip=True)
    data.append({'text': element})
    content = soup.find("div", id="newscontent")
    for element in content.find_all(["p", "figure"]):
        if element.name=="p":
            if element.get_text(strip=True) and not element.find('br'):
                data.append({'text': element.get_text(strip=True)})
        elif element.name=="figure" and "fr-img-wrap" in element.get('class', []):
            img_tag = element.find('img')
            if img_tag and img_tag.get('src'):
                # 如果有圖片，則獲取圖片的 src
                img_src = img_tag['src']
                
                # 查找圖片說明 <figcaption>
                figcaption = element.find('figcaption')
                caption_text = figcaption.get_text(strip=True) if figcaption else None
                
                # 將圖片的 src 和說明一起儲存
                data.append({'img': img_src, 'caption': caption_text})

    # data = json.dumps(data, ensure_ascii=False, indent=4)
    # print(data)

    with open("output.json", "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=4)


    # 關鍵字
    keyword = []
    news_tag = soup.find("div", class_="news-tag")
    news_tag = news_tag.find_all("li")
    for ky in news_tag:
        key = ky.find("a").text
        keyword.append(key)
    
    print(keyword)

    driver.quit()
    return


news_crawler("https://www.ftvnews.com.tw/news/detail/2025428N08M1", "罷免")


def group_crawler(url, type):

    if type=="熱門" or type=="體育" or type=="財經" or type=="數位專題":
        return

    # 設定 Chrome 執行選項
    options = Options()
    options.add_argument("--disable-gpu")
    options.add_argument("window-size=1920x1080")

    # 設定 ChromeDriver 路徑
    driver_path = os.path.join(os.path.dirname(__file__), '..', 'chromedriver.exe')
    service = Service(executable_path=driver_path)

    # 啟動瀏覽器
    driver = webdriver.Chrome(service=service, options=options)
    driver.get(url)

    time.sleep(2)  # ⏳ 等一下內容跑完（重要！網頁是動態 JS）

    if type=="即時":
        # 讓頁面一直滑到底
        last_height = driver.execute_script("return document.body.scrollHeight")

        while True:
            # 滑到最底
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")

            # 等待新內容載入
            time.sleep(2)

            # 重新計算 scroll 高度
            new_height = driver.execute_script("return document.body.scrollHeight")

            if new_height == last_height:
                print("✅ 到底了，停止滑動")
                break

            last_height = new_height
    
    # 抓 HTML 原始碼
    html = driver.page_source
    driver.quit()

    soup = BeautifulSoup(html, "html.parser")

    news_item = soup.find_all("li", class_="rl-list col-12")

    
    for news in news_item:
        a_tag = news.find("a", class_="img-block")
        if a_tag:
            news_link = a_tag.get("href")
            news_link = FTV_Main_url + news_link
            news_crawler(news_link, type)
        print(news_link)

    return


    fileName = "FTV_" + type
    # 存成 html 檔方便除錯
    # if not os.path.exists(f"{fileName}.html"):
    with open(f"{fileName}.html", "w", encoding="utf-8") as f:
        f.write(html)
    print(f"✅ 已儲存 {fileName}.html")

    if type=="首頁" or type=="體育":
        return
    

def main():

    # 設定 Chrome 執行選項
    options = Options()
    options.add_argument("--disable-gpu")
    options.add_argument("window-size=1920x1080")

    # 設定 ChromeDriver 路徑
    driver_path = os.path.join(os.path.dirname(__file__), '..', 'chromedriver.exe')
    service = Service(executable_path=driver_path)

    # 啟動瀏覽器
    driver = webdriver.Chrome(service=service, options=options)
    driver.get(FTV_Main_url)

    time.sleep(2)  # ⏳ 等一下內容跑完（重要！網頁是動態 JS）

    # 抓 HTML 原始碼
    html = driver.page_source
    driver.quit()


    # 存成 html 檔方便除錯
    with open("FTV_Main.html", "w", encoding="utf-8") as f:
        f.write(html)
    print("✅ 已儲存 HTML")

    # 使用 BeautifulSoup 解析
    soup = BeautifulSoup(html, "html.parser")

    # 印出連結
    Menulist = soup.find_all("li", class_ = "mainMenu")


    allow_href = ["http", "https"]

    for link in Menulist:
        group = link.find("a")
        group_href = group.get("href")
        group_text = group.text
        extension = group_href.split(":")[0].lower()
        if not extension in allow_href:
            group_href = FTV_Main_url + group_href
        
        group_crawler(group_href, group_text)


# main()







































"""
import undetected_chromedriver as uc
from bs4 import BeautifulSoup
import time

url = "https://www.ftvnews.com.tw/"

chrome_options = uc.ChromeOptions()
chrome_options.add_argument("--window-size=1920,1080")
chrome_options.add_argument("--disable-gpu")
chrome_options.add_argument(
    "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36"
)


with uc.Chrome(options=chrome_options) as driver:
    driver.get(url)
    time.sleep(5)
    html = driver.page_source

# 存成 html 檔
with open("FTV_Main.html", "w", encoding="utf-8") as f:
    f.write(html)
print("✅ HTML 已儲存")

# 分析
soup = BeautifulSoup(html, "html.parser")
for h2 in soup.find_all("h2"):
    print("📰", h2.get_text(strip=True))

try:
    driver.quit()
except Exception as e:
    print("⚠️ 關閉瀏覽器時發生錯誤（可忽略）：", e)
"""
"""
import undetected_chromedriver as uc
from selenium.webdriver.chrome.service import Service
from bs4 import BeautifulSoup
import time
import os

# 設定 Chrome 執行選項
options = uc.ChromeOptions()
options.add_argument("--disable-gpu")
options.add_argument("window-size=1920x1080")

# 設定 ChromeDriver 路徑
driver_path = os.path.join(os.path.dirname(__file__), '..', 'chromedriver.exe')

# 創建 ChromeDriver 服務
service = Service(executable_path=driver_path)

# 啟動瀏覽器
with uc.Chrome(service=service, options=options) as driver:
    driver.get("https://www.ftvnews.com.tw/")

    time.sleep(5)  # ⏳ 等一下內容跑完（重要！網頁是動態 JS）

    # 抓 HTML 原始碼
    html = driver.page_source

    # 存成 html 檔方便除錯
    with open("FTV_Main.html", "w", encoding="utf-8") as f:
        f.write(html)
    print("✅ 已儲存 HTML")

    # 使用 BeautifulSoup 解析
    soup = BeautifulSoup(html, "html.parser")

    # 嘗試印出所有 h2 標題（根據實際網頁調整標籤）
    for h2 in soup.find_all("h2"):
        print("📰", h2.get_text(strip=True))
"""
