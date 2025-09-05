function locationSearch ( search_form, search_item, str ) {

    let sql = `
        SELECT * 
        FROM 
            ${search_form} 
        WHERE 
            LOWER(${search_item}_en)    LIKE LOWER( ? ) OR 
            LOWER(${search_item}_zh_tw) LIKE LOWER( ? ) OR 
            LOWER(${search_item}_zh_cn) LIKE LOWER( ? )
    `;

    let params = [
        `${str}`,
        `${str}`,
        `${str}`
    ];

    return { sql, params };
}

function temp_exactSearch ( search_form, search_item, str ) {

    let quesStr = '';
    let substr_list = [];
    let left=0, right=1
    while( !( right == str.length && left == right ) ) {
        let substr = str.slice(left, right);
        substr_list.push(substr.toLowerCase());

        if ( quesStr ) quesStr += ', ?';
        else quesStr += '?';

        if ( right == str.length ) left += 1;
        else right += 1;
    }
    //console.log(`\n\nsubstr_list: \n${substr_list}\n\n`);

    let sql = `
        SELECT * 
        FROM 
            ${search_form} 
        WHERE 
            LOWER(${search_item}_en)    LIKE LOWER( ? ) OR 
            LOWER(${search_item}_zh_tw) LIKE LOWER( ? ) OR 
            LOWER(${search_item}_zh_cn) LIKE LOWER( ? ) OR
            LOWER(${search_item}_en)    IN   ( ${quesStr} ) OR 
            LOWER(${search_item}_zh_tw) IN   ( ${quesStr} ) OR 
            LOWER(${search_item}_zh_cn) IN   ( ${quesStr} );
    `;

    let params = [
        `${str}%`,
        `${str}%`,
        `${str}%`,
        ...substr_list,
        ...substr_list,
        ...substr_list
    ];

    //return formatSql(sql, params)
    return { sql, params };
}

/*function formatSql(sql, params) {
    // 遍歷 params 替換 SQL 中的問號
    params.forEach(param => {
        sql = sql.replace('?', `'${param}'`);
    });
    return sql;
}

function build_next() {

}

function caculateStringSimulate() {

}*/

module.exports = { locationSearch };