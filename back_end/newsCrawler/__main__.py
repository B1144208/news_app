import os
import sys
import time
import readchar
import traceback # 必須匯入 traceback

# 確保當前目錄下的模組可以被正確導入（支援 newsCrawler/FTV_Crawler 等子模組）
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# crawlerData
from newsCrawler.object import CrawlerData

# 載入新聞網站模組
from newsCrawler.crawlerWeb.FTV_Crawler import ftv_crawler

from newsCrawler.crawlerWeb.BBC.bbc_spider import run as bbc_crawler_run
from newsCrawler.crawlerWeb.USAToday.usatoday_spider import run as usatoday_run
from newsCrawler.crawlerWeb.MOB.mob import run as mob_crawler_run

# 選擇 channel
def ask_choice(prompt="Please input the channel_id [1-4]: "):
    valid = {"1", "2", "3", "4"}
    while True:
        print(prompt, end='', flush=True)
        ch = readchar.readchar()    # 立刻回傳單一字元
        print(ch)
        if ch in valid:
            return ch
        elif ch in ("\x03", "\x1b"): # Ctrl+C, Esc
            print ("Canceled")
            return None
        else:
            print("\nOnly access number [1-4], please input again.")

def run():
    # 選擇 channel_id
    choice = ask_choice()
    if choice is None:
        sys.exit(1)

    crawlerData = CrawlerData ( channel_id = choice )

    match choice:
        case '1':
            #ftv_crawler.run(crawlerData)
            try:
                while(1):
                    try:
                        ftv_crawler.run(crawlerData)
                    except Exception as e:
                        pass

                    time.sleep(60)
            except KeyboardInterrupt:
                print("收到中斷訊號，停止爬蟲。")
        case '2':
            print("todo: channel 2")

        # 修正後的 case '3' 區塊
        case '3':
            while True:
                try:
                    # 1. 觸發 BBC 爬蟲
                    print("\n--- 新一輪爬取任務開始 ---")
                    #bbc_crawler_run(crawlerData)

                    # 2. BBC 結束後，觸發 USA 爬蟲
                    #usatoday_run(crawlerData)

                    mob_crawler_run(crawlerData)

                    # 3. USA 也結束後，等待 10 分鐘 (600 秒)
                    print("\n所有爬蟲任務完成，將於 10 分鐘後重新開始...")
                    time.sleep(30)

                except KeyboardInterrupt:
                    print("\n收到中斷訊號，停止爬蟲。")
                    sys.exit(0)

                except Exception as e:
                    print(f"❌ 爬蟲執行發生錯誤: {e}")
                    traceback.print_exc()

        case '4':
            print("todo: channel 4")
        case '5':
            print("todo: channel 5")
        case _:
            print("unexpected choice")

if __name__ == "__main__":
    run()