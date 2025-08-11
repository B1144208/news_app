routes req:
0.  example
    a.  search {}
    b.  insert {}
    c.  update {}
    d.  delete {}

1.  news
    a.  search { none ( need to add )}
    b.  insert {
            body: { url, channel, cover_img, news_title, publish_date, detail, group, location, keyword }
        }
    c.  update {}
    d.  delete {
            params: id,
            body: image_id, relation_id
        }

2.  channel
    a.  search {
            query: name
        }
    b.  insert {
            body: { url, img, name, type, update_rate, introduce }
        }
    c.  update {}
    d.  delete {
            params: id,
            query: 'has'
        }

3.  image
    a.  search {
            body: { src, alt }
        }
    b.  insert {
            body: { src, alt }
        }
    c.  update {}
    d.  delete {
            params: id,
            query: 'has'
        }

4.  group
    a.  search {
            query: name
        }
    b.  insert {
            body: { id, name }
        }
    c.  update {}
    d.  delete {}

5.  location
    a.  search {
            query: name
        }
    b.  insert {}
    c.  update {}
    d.  delete {}

6.  relation
    a.  search { 
            query: id, 'relation_keyword',
            body: { keyword }
        } (4b.) not complete
    b.  insert {
            body: { keyword }
        }
    c.  update {}
    d.  delete {
            params: id,
            query: 'has'
        }

7.  keyword
    a.  search {
            query: text
        }
    b.  insert {
            query: text
        }
    c.  update {}
    d.  delete {
            params: id
        }


*.  test
    a.  crf    { none }