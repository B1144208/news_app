import os
import sys
import time
import readchar

# 確保當前目錄下的模組可以被正確導入（支援 newsCrawler/FTV_Crawler 等子模組）
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# crawlerData
from newsCrawler.object import CrawlerData

# 載入新聞網站模組
from newsCrawler.crawlerWeb.FTV_Crawler import ftv_crawler

# 選擇 channel
def ask_choice(prompt="Please input the channel_id [1-4]: "):
    valid = {"1", "2", "3", "4"}
    while True:
        print(prompt, end='', flush=True)
        ch = readchar.readchar()    # 立刻回傳單一字元
        print(ch)
        if ch in valid:
            return ch
        elif ch in ("\x03", "x1b"): # Ctrl+C, Esc
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
        case '3':
            print("todo: channel 3")
        case '4':    
            print("todo: channel 4")
        case _:
            print("unexpected choice")

if __name__ == "__main__":
    run()
