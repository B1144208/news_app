async function checkRequireField ( requireFields, funcName="Unknown Function" ) {
    /*
    @ Check Require Field
    @ field, data: necessary raw
    @ type  : number, string, image, array, object
    @ other : [ jump, lth, non_null, non_trim, non_string_number, string_into_array, news_detail ]
    @       1. jump : 若 invalidType 或 nonNull && isNull 時, 則直接跳過
    @       2. lth  : Lenient Type Handling (寬鬆型別處理) 若 type 錯誤, 則設成 null
    @       3. non_null : 不能為空
    @       4. non_change: 只判斷是否error，正確則不回傳值
    @       5. non_string_number : 不允許 string 型態的 number
    @       6. number_into_array: 若是 array, 則 each trim() ; 若是 number, 轉 array
    @       6. string_into_array: 若是 array, 則 each trim() ; 若是 string, 先 trim() 後再轉 array
    @       7. news_detail: detail 處理
    @ array_filter : type ( 過濾 array 中的值 )
    @ enum  : [] 可以包含的值
    */
    
    let errors = [];
    let newData = [];

    for (const fieldObj of requireFields) {
        
        const { field, data, type, other, array_filter: array_type, enum:enum_value } = fieldObj;

        // 檢查 必須有 field, data
        if ( (!('field' in fieldObj) || !typeof field === 'string' || !field.trim() === '') || !('data' in fieldObj) ) {
            errors.push(`Missing 'field' or 'data'`);
            continue;
        }
        let changeData = data;

        // 處理 other 資料格式
        const hasOther = ('other' in fieldObj)? true: false;
        if ( hasOther && !Array.isArray(other) ) {
            errors.push(`'${field}' has a invalid 'other'`);
            continue;
        }
        const jump = (hasOther && other.includes('jump'))? true: false;
        const lth = (hasOther && other.includes('lth'))? true: false;
        const nonNull = (hasOther && other.includes('non_null'))? true: false;
        const nonChange = (hasOther && other.includes('non_change'))? true: false;
        const nonStringNumber = (hasOther && other.includes('non_string_number'))? true: false;
        const numberIntoArray = (hasOther && other.includes('number_into_array'))? true: false;
        const stringIntoArray = (hasOther && other.includes('string_into_array'))? true: false;
        const detail = (hasOther && other.includes('news_detail'))? true: false;
        
        // 處理 其他 資料格式
        const arrayFilter = ('array_filter' in fieldObj)? true: false;
        const hasEnum = ('enum' in fieldObj)? true: false;

        // 若資料為空且可以為空
        if ( checkDataNull ( changeData ) ) {
            if ( jump && nonNull ) continue;
            nonNull? 
                errors.push(`'${field}' 11 must not be null`): 
                !nonChange && ( newData.push( changeData ) );
            continue;
        }

        // 判斷 type 是否 invalid
        let validType = null;

        if ( type ) {
            switch ( type ) {
                case 'number': 
                    if( nonStringNumber ) validType = typeof changeData === 'number';
                    else {
                        validType = typeof changeData === 'number' || !isNaN( changeData );
                        if ( validType ) !nonChange && ( changeData = Number(changeData) );
                    }
                    break;
                case 'string':
                    validType = typeof changeData === 'string';
                    if ( validType) !nonChange && ( changeData = changeData.trim() );
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
                            !nonChange && ( changeData = checkDateTimeFormat(changeData.trim()) );
                        } catch (err) {
                            validType = false;
                        }
                    }
                    break;
                case 'array': 
                    validType = Array.isArray(changeData);
                    // number_into_array
                    if ( numberIntoArray && !validType ) {
                        if( nonStringNumber ) validType = typeof changeData === 'number';
                        else {
                            validType = typeof changeData === 'number' || !isNaN( changeData );
                            if ( validType ) !nonChange && ( changeData = Number(changeData) );
                        }
                        !nonChange && ( changeData = [changeData] );
                        validType = true;
                    }

                    // string_into_array
                    if ( stringIntoArray && !validType && typeof changeData === 'string') {
                        !nonChange && ( changeData = [changeData] );
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

        // 如果沒有 other & arrayFilter & hasEnum
        if ( !hasOther && arrayFilter && hasEnum) {
            !nonChange && ( newData.push( changeData ) );
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
            !nonChange && ( changeData = null );
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
                    requireFields.push({ field: `detail[${index}]`, data: isText? item.text: item.img, type: isText?'string': 'image', other: ['jump', 'non_null'] });
                }
            });
            try {
                !nonChange && ( changeData = await checkRequireField ( requireFields ) );
            } catch (err) {
                !nonChange && ( changeData = null );
            }
        }

        // array_filter
        if ( arrayFilter ) {
            if ( type !== 'array' ) {
                err = new Error (`array_filter has a invalid use, type need array`);
                err.desc = `${funcName}: checkRequireField Error`;
                throw err;
            }
            let requireFields = [];
            changeData.map ( (item, index) => requireFields.push({ field: `arrayFilter[${index}]`, data: item, type: array_type, other: ['jump', 'non_null'] }));
            try {
                !nonChange && ( changeData = await checkRequireField ( requireFields ) );
            } catch (err) {
                !nonChange && ( changeData = null );
            }
        }

        // enum
        if ( hasEnum && !( !data && lth ) ) {
            const includeEnum = enum_value.includes( data );
            ( !includeEnum && !lth ) && ( errors.push(`'${field}' has an error input`) );
        }
        
        // 檢查資料為空
        if ( checkDataNull ( changeData ) ) {
            if ( jump && nonNull ) continue;
            nonNull? 
                errors.push(`'${field}' must not be null`): 
                !nonChange && ( changeData = null );
        }

       !nonChange && ( newData.push( changeData ) );

    };

    if ( errors.length !==0 ) {
        err = new Error (`checkRequireField Check Error\n${errors.join('\n')}`);
        err.desc = `${funcName}: checkRequireField Error`;
        throw err;
    }

    return newData;
}

function checkDataNull ( data ) {
    // check null - string, array, object

    let isNull = false;
    if ( data === null || data === undefined ) isNull = true;
    else if ( typeof data === 'string' && data.trim() === '' ) isNull = true;
    else if ( Array.isArray( data ) && data.length === 0 ) isNull = true;
    else if ( typeof data === 'object' && Object.keys(data).length === 0 ) isNull = true;

    return isNull;
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

function checkDateTimeFormat (input) {
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


module.exports = { checkRequireField, checkImageFormat, checkDateTimeFormat };

