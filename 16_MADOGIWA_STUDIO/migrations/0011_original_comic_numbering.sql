-- The external note article retains its own numbering; omit its chapter count.
UPDATE articles
SET copy = replace(copy, '全14話の原作漫画', '原作漫画')
WHERE slug = 'original-comic';
