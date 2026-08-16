INSERT INTO episodes (id, slug, episode_number, title, summary, status)
VALUES (
  '00000000-0000-4000-8000-000000000040',
  'sobaya-beer-battery',
  40,
  'そば屋ビールバッテリー',
  '極度乾燥ビールをめぐる、オフィスでの短編エピソード。',
  'draft'
);

INSERT INTO prompt_versions (id, episode_id, label, body, version, is_current, created_by)
VALUES (
  '10000000-0000-4000-8000-000000000040',
  '00000000-0000-4000-8000-000000000040',
  'Seedance 2.0 — Clip A',
  'このデモデータは管理画面の表示確認用です。実際に採用した prompt_clip_a.txt の内容へ管理画面またはMCPから更新してください。',
  1,
  1,
  'migration'
);
