
async function checkRequireField ( requireFields ) {
    /*
    @ Check Require Field
    @ field, data: necessary raw
    @ type : number, string, image, array, object
    @ other: [null]
    */
    
    let errors = [];
    let newData = [];

    requireFields.map ( fieldObj => {
        
        const { field, data, type, other } = fieldObj;
        
        // 檢查 必須有 field, data
        if ( !field || !typeof field === 'string' || !field.trim() === '' ) {
            errors.push(`Missing 'field'`);
            return data;
        }

        // 判斷 type 是否 invalid
        let validType = false;
        if ( type ) {
            switch ( type ){
                case 'number': 
                    if ( !(validType = typeof data === 'number') )
                        errors.push(`${field} must be a number`);
                    break;
                case 'string':
                    if ( !(validType = typeof data === 'string' && data.trim() === '') )
                        errors.push(`${field} must be a string`);
                    data = data.trim();
                    break;
                case 'image': 
                    try {
                        //data = await checkImageFormat ( data )
                        validType = Boolean(data);
                        if ( !validType ) {
                            errors.push(`${field} must be a image`);
                        }
                    } catch (err) {
                        throw err;
                    }
                    break;
                case 'array': 
                    validType = Array.isArray(data);
                    if ( !validType ) {
                        errors.push(`${field} must be a array`);
                    }
                    break;
                case 'object': 
                    validType = typeof data === 'object';
                    if ( !validType ) {
                        errors.push(`${field} must be a object`);
                    }
                    break;
                default:
                    errors.push(`Valid 'type'`);
                    break;
            }
        }

        const allowNull = other.includes('null');
        

        //if ( ( allowNull && ( data === undefined || data === null )))

        


    });

    
}

async function checkImageFormat( img ) {

    // 若 img 不存在或不是 object，直接回傳 null
    if (!img || typeof img !== 'object') {
        return null;
    }

    const hasSrc = 'src' in img;
    const hasAlt = 'alt' in img;

    // 若沒有 src 或 src 是空的字串，回傳 null
    if (!hasSrc || !img.src || img.src.trim() === '') {
        return null;
    }

    // 如果沒有 alt，就補 null
    if (!hasAlt) {
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

