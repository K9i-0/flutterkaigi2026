-- Display-name change only: retain stable member IDs and relations.
UPDATE members
SET name = '福ギュン'
WHERE id = 'fukuchan';

-- Update public editorial copy; preserve slugs, media filenames and generation inputs.
UPDATE episodes
SET title = replace(title, '福ちゃん', '福ギュン'),
    summary = replace(summary, '福ちゃん', '福ギュン')
WHERE instr(title, '福ちゃん') > 0 OR instr(summary, '福ちゃん') > 0;

UPDATE gallery_items
SET title = replace(title, '福ちゃん', '福ギュン')
WHERE instr(title, '福ちゃん') > 0;

UPDATE articles
SET title = replace(title, '福ちゃん', '福ギュン'),
    copy = replace(copy, '福ちゃん', '福ギュン')
WHERE instr(title, '福ちゃん') > 0 OR instr(copy, '福ちゃん') > 0;
