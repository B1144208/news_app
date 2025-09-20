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
    driver = utils.init_steal_driver(USER_AGENT, False)
    
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
    errLog = ErrorLog (
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

    errLog.clean_json()
    print("========== FTV_NEWS 擷取完成 ==========\n")
    return




    ### 測試 extract_news_urls
    #function_news.extract_news_urls(FTV_Main_url, "https://www.ftvnews.com.tw/tag/時尚", "時尚", driver)
    ### 測試 get_news_information
    """
    #news_urls = [ "https://www.ftvnews.com.tw/news/detail/2025628W0295", "https://www.ftvnews.com.tw/news/detail/2025628N01M1"] #沒有channe;
    news_urls = ["https://www.ftvnews.com.tw/news/detail/2021423W0141"]
    function_news.get_news_information(news_urls, driver, GROUP="快新聞")
    """
    """
    # news_urls = ["https://www.ftvnews.com.tw/news/detail/2021618W0199"] # alter order 未處理
    news_urls = ["https://www.ftvnews.com.tw/news/detail/2021423W0141"]
    function_news.get_news_information(news_urls, driver, CHANNEL="Cookpad")
    """
    ### 測試 start_channel_collection
    """
    channel_list = function_channel.start_channel_collection(FTV_Main_url, "authors", driver)
    print(f"\n\nchannel_list:\n{channel_list}\n")
    """
    ### 測試 AUTHOR_UNKNOWN_save_to_AUTHOR_CLASSIFY
    """
    function_channel.AUTHOR_UNKNOWN_save_to_AUTHOR_CLASSIFY()
    """
    ### 測試 get_channel_information
    channels = [
        {
            "href": "https://www.ftvnews.com.tw/author/9",
            "tag": "channel"
        },
        {
            "href": "https://www.ftvnews.com.tw/author/7",
            "tag": "channel"
        },
        {
            "href": "https://www.ftvnews.com.tw/author/4",
            "tag": "channel"
        }
    ]
    #function_channel.get_channel_information(FTV_Main_url, channels, driver)
    #print(f"channel_list:\n{channel_list}")
    """
        {
            "href": "https://www.ftvnews.com.tw/author/87",    # 1頁 channel
            "tag": "channel"
        },
        {
            "href": "https://www.ftvnews.com.tw/author/90",     # 2頁 channel
            "tag": "channel"
        },
        {
            "href": "https://www.ftvnews.com.tw/author/142",     # 1頁 people
            "tag": "people"
        }
    """



if __name__ == "__main__":
    crawlerData = utils.CrawlerData(channel_id=1)
    run( crawlerData )