import os
import sys

from pathlib import Path
from functools import partial

from .function_news import start_news_collection, extract_news_urls, get_news_information
from . import function_channel
from newsCrawler import utils
from newsCrawler.object import CrawlerQueue, ErrorLog

def run( crawler_data ):

    # 首頁連結
    FTV_Main_url = "https://www.ftvnews.com.tw"

    # chrome 啟動器
    USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36"
    driver = utils.init_steal_driver(USER_AGENT, True)
    
    # create crawlerData
    crawlerData = crawler_data

    # create newsQueue
    newsQueue = CrawlerQueue (
        name = "FTV",
        kind = "news",
        crawler_data = crawlerData,
        save_into_json = True
    )
    
    # create ErrorLog
    ErrorLog (
        name = "FTV-errLog",
        path = Path(__file__).resolve().parent,
        fn_map = [
            [start_news_collection, ["BASE_URL", "crawlerData", "newsQueue", "driver"]],
            [extract_news_urls, ["BASE_URL", "SUB_URL", "crawlerData", "newsQueue", "driver", "breakPage"]],
            [get_news_information, ["NEWS_URLS", "crawlerData", "newsQueue", "driver", "GROUP", "CHANNEL"]]
        ],
        # 先傳 json 無法儲存的資料，新建的 crawlerData, newsQueue, driver
        init_data = {
            "crawlerData": crawlerData,
            "newsQueue": newsQueue,
            "driver": driver
        },
        entry = partial(start_news_collection, FTV_Main_url, crawlerData, newsQueue, driver)
    )

    # 首頁入口
    #start_news_collection(FTV_Main_url, crawlerData, newsQueue, driver)

    # 專欄作者入口
    #function_channel.start_channel_collection(FTV_Main_url, "authors", driver)

    driver.quit()
    
    newsQueue._graceful_backup()
    newsQueue.stop_autobackup()

    print("========== FTV_NEWS 擷取完成 ==========\n")
    return


if __name__ == "__main__":
    crawlerData = utils.CrawlerData(channel_id=1)
    run( crawlerData )