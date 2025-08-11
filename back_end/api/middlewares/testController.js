const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');


// search
async function testCheckRequireField (req, res, next) {
    //const { field, data, type, other } = req.body;

    // type: number, string, image, datetime, array, object

    let a1, b2, c3, d4, e5, f6;

    a1 = "    sg   -     ";
    b2 = {
      "src": '1531',
      "alt": 153
    };
    c3 = "  2025-07-02 21:13";
    d4 = [
      {
        "text": "即時中心／廖予瑄報導"
      },
      {
        "text": "新功能！Meta公司經營的社群平台Threads在今（2）日正式推出獨立聊天室功能，讓民眾不用再透過Instagram（IG）的聊天室，就能直接傳送訊息。沒想到功能一推出，卻引發網上哀鴻遍野，紛紛苦求Meta將這項功能停用。"
      },
      {
        "text": 1235
      },
      {
        "text": "今日一早有不少人便發現Threads推出新功能，打開app便可以看到下方功能列中，左邊數來第2個圖示，多出一個信封符號，點進去便可以開啟收件匣。"
      },
      {
        "img": {
          "src": "https://cdn.ftvnews.com.tw/summernotefiles/News/5c727744-a209-428b-929a-fbc65619b3ad.jpg",
          "alt": "Threads的app下方功能列，左邊數來第2個信封圖示便是收件匣。（圖／擷取自Threads）"
        }
      },
      {
        "text": 4565
      },
      {
        "text": "此外，雖然現在Threads有專屬的聊天室了，但仍可以將貼文分享到IG聊天室，只需要多一個步驟：點選分享鍵後，選取「Instagram 訊息分享」，再選擇要分享的IG帳號，便可以用IG聊天室將想分享的貼文傳送給好友。"
      },
      {
        "img": {
          "src": 8888
      
        }
      },
      {
        "text": "沒想到，這項新功能推出後，卻引來一片罵聲，許多網友直接在Threads官方帳號的貼文下方指出，「這太糟糕了」、「沒人要求需要這項功能」，甚至有人直言，「可以將這項功能停用嗎？」"
      }
    ];
    e5 = null;
    f6 = [null];
    console.log(`f6: ${f6.length}`);
    let requireFields = [];
    requireFields.push (
        /*{ field: 'a1', data: a1, type: 'string', need: ['non_null'] },
        { field: 'b2', data: b2, type: 'image', need: ['lth']},
        { field: 'c3', data: c3, type: 'datetime', need: ['non_null'] },
        { field: 'd4', data: d4, type: 'object', need: ['non_null'], other: ['news_detail'] },
        { field: 'e5', data: e5, type: 'number', need: ['non_string_number'] },*/
        { field: 'f6', data: f6, type: 'array', other: ['string_into_array'] }
    );
    
    let result;
    try {
        result = await checkRequireField ( requireFields );

        //[ a1, b2, c3, d4, e5, f6 ] = result;
        //console.log (result);
    } catch (err) {
        err.desc = "middlewares - testCheckRequireField(): Test Error";
        return next(err);
    }
    

    
    return res.apiSuccess(result, 'Check Success');
    
}

module.exports = {
    testCheckRequireField
}