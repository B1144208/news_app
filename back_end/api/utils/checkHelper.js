

async function checkRequireField ( requireFields ) {
    /*
    @ Check Require Field
    @ field, data: necessary raw
    @ type  : number, string, image, array, object
    @ need  : [ jump, lth, non_null, non_string_number ]
    @       1. jump : 若 type 錯誤, 則直接跳過
    @       2. lth  : Lenient Type Handling (寬鬆型別處理) 若 type 錯誤, 則設成 null
    @       3. non_null : 不能為空
    @       4. non_string_number : 不允許 string 型態的 number
    @ other : [ news_detail, string_into_array ]
    @       1. news_detail: detail 處理
    @       2. string_into_array: 若是 array, 則 each trim() ; 若是 string, 先 trim() 後再轉 array
    */
    
    
    let errors = [];
    let newData = [];

    for (const fieldObj of requireFields) {
        
        const { field, data, type, other, need } = fieldObj;

        // 檢查 必須有 field, data
        if ( (!('field' in fieldObj) || !typeof field === 'string' || !field.trim() === '') || !('data' in fieldObj) ) {
            errors.push(`Missing 'field' or 'data'`);
            continue;
        }
        let changeData = data;

        // 處理 need 資料格式
        let hasNeed = ('need' in fieldObj)? true: false;
        if ( hasNeed && !Array.isArray(need) ) {
            errors.push(`'${field}' has a invalid 'need'`);
            continue;
        }
        const jump = (hasNeed && need.includes('jump'))? true: false;
        const lth = (hasNeed && need.includes('lth'))? true: false;
        const nonNull = (hasNeed && need.includes('non_null'))? true: false;

        // 處理 other 資料格式
        let hasOther = ('other' in fieldObj)? true: false;
        if ( hasOther && !Array.isArray(other) ) {
            errors.push(`'${field}' has a invalid 'other'`);
            continue;
        }
        const detail = (hasOther && other.includes('news_detail'))? true: false;
        const sia = (hasOther && other.includes('string_into_array'))? true: false;
        

        // 若資料為空且可以為空
        if ( changeData===null || changeData===undefined ) {
            if ( jump && nonNull ) continue;
            nonNull? errors.push(`'${field}' must not be null`): newData.push( changeData );
            continue;
        }

        // 判斷 type 是否 invalid
        let validType = null;

        if ( type ) {
            switch ( type ) {
                case 'number': 
                    validType = typeof changeData === 'number' || !isNaN( changeData );
                    if( need && need.includes('non_string_number') ) validType = typeof changeData === 'number';
                    break;
                case 'string':
                    validType = typeof changeData === 'string';
                    if ( validType ) changeData = changeData.trim();
                    break;
                case 'image':
                    try {
                        changeData = await checkImageFormat ( data );
                        validType = Boolean(changeData);
                    } catch (err) {
                        validType = false;
                    }
                    break;
                case 'datetime':
                    validType = (typeof changeData === 'string' || changeData.trim() !== '');
                    if ( validType ) {
                        try {
                            changeData = formatDateTimeForSQL(changeData.trim());
                        } catch (err) {
                            validType = false;
                        }
                    }
                    break;
                case 'array': 
                    validType = Array.isArray(changeData);
                    // string_into_array
                    if ( sia && !validType && typeof changeData === 'string' ) {
                        changeData = [changeData];
                        validType = true;
                    }
                    break;
                case 'object': 
                    validType = typeof changeData === 'object';
                    break;
                default:
                    errors.push(`'${field}' has a invalid 'type'`);
                    continue;
            }

            if ( !validType ) {
                errors.push(`'${field}' must be a ${type}`);
            }
        }

        // 如果沒有 need & other
        if ( !hasNeed && !hasOther ) {
            newData.push( changeData );
            continue;
        }
        // type 判別錯誤，直接跳過
        if ( !validType && jump ) {
            errors.pop();
            continue;
        }
        // type 判別錯誤，但以寬鬆型別處理 ( lth )
        if ( !validType && lth ) {
            errors.pop();
            changeData = null;
            validType = true;
        }

        // news_detail 處理
        if ( detail ) {
            let requireFields = []
            data.map ( (item, index) => {
                // 跳過空字串
                if ( typeof item !== 'object' || item === null ) return;

                // 檢查 text, img
                if ( 'text' in item || 'img' in item) {
                    let isText = 'text' in item
                    requireFields.push({ field: `detail[${index}]`, data: isText? item.text: item.img, type: isText?'string': 'image', need: ['jump', 'non_null'] });
                }
            });

            try {
                changeData = await checkRequireField ( requireFields );
            } catch (err) {
                changeData = null;
            }
        }

        // string_into_array 處理
        if ( sia ) {
            if ( type !== 'array' ) {
                err = new Error (`utils-checkRequireField(): string_into_array has a invalid use, type need array`);
                throw err;
            }
            // array 處理
            let requireFields = [];
            changeData.map ( (item, index) => requireFields.push({ field: `sia[${index}]`, data: item, type: 'string', need: ['jump', 'non_null'] }));
            try {
                changeData = await checkRequireField ( requireFields );
            } catch (err) {
                changeData = null;
            }
        }

        // check null - string, array, object
        let isNull = false;
        if ( changeData === null || changeData === undefined ) isNull = true;
        else if ( typeof changeData === 'string' && changeData.trim() === '' ) isNull = true;
        else if ( Array.isArray( changeData ) && changeData.length === 0 ) isNull = true;
        else if ( typeof changeData === 'object' && Object.keys(changeData).length === 0 ) isNull = true;

        // 不能為 null
        if ( isNull ) {
            nonNull? errors.push(`'${field}' must not be null`): changeData = null;
        }
        newData.push( changeData );

    };

    if ( errors.length !==0 ) {
        err = new Error (`utils-checkRequireField(): check Error\n${errors}`);
        throw err;
    }

    return newData;
    
}

async function checkImageFormat( img ) {

    // 若 img 不存在或不是 object，直接回傳 null
    if (!img || typeof img !== 'object') {
        return null;
    }

    const hasSrc = 'src' in img;
    const hasAlt = 'alt' in img;

    // 若沒有 src 或 src 是空的字串，回傳 null
    if ( !hasSrc || ( hasSrc && ( !img.src || typeof img.src !== 'string' || img.src.trim() === '' ) ) ) {
        return null;
    }

    // 如果沒有 alt，就補 null
    if ( !hasAlt || ( hasAlt && (typeof img.alt !== 'string' || img.alt.trim() === '') ) ) {
        img.alt = null;
    }

    return img;
}

function formatDateTimeForSQL(input) {
    if (typeof input !== 'string') throw new Error('Invalid input: not a string');

    // 1. 把斜線換成 dash
    let str = input.replace(/\//g, '-');

    // 2. 確保有「空格」把日期時間分開（防止 `T` 之類）
    str = str.replace('T', ' ');

    // 3. 如果只到分鐘，自動補上秒數
    if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(str)) {
        str += ':00';
    }

    // 4. 驗證完整格式
    const dateTimeRegex = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/;
    if (!dateTimeRegex.test(str)) {
        throw new Error('Invalid datetime format. Expected: YYYY-MM-DD HH:mm:ss');
    }

    return str;
}


module.exports = { checkRequireField, checkImageFormat, formatDateTimeForSQL };

