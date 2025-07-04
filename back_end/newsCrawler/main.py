import os
import sys

# 確保當前目錄下的模組可以被正確導入（支援 newsCrawler/FTV_Crawler 等子模組）
sys.path.append(os.path.dirname(os.path.abspath(__file__)))


# 載入模組
from newsCrawler.FTV_Crawler import crawler

if __name__ == "__main__":
    crawler.run()