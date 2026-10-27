-- Partidas iniciadas no servidor (semente sorteada aqui) e pontuações
-- publicadas no ranking. Sem dado pessoal: device é um id aleatório do
-- jogo; ip_hash é hash salgado e diário (só pra limite de partidas).
CREATE TABLE IF NOT EXISTS runs (
  id TEXT PRIMARY KEY,
  device TEXT NOT NULL,
  ip_hash TEXT NOT NULL,
  seed INTEGER NOT NULL,
  rank_index INTEGER NOT NULL,
  config TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  finished_at INTEGER,
  outcome INTEGER,
  score INTEGER,
  hours INTEGER,
  wrong_cities INTEGER,
  city TEXT
);
CREATE INDEX IF NOT EXISTS runs_device_created ON runs (device, created_at);
CREATE INDEX IF NOT EXISTS runs_ip_created ON runs (ip_hash, created_at);

CREATE TABLE IF NOT EXISTS scores (
  run_id TEXT PRIMARY KEY REFERENCES runs (id),
  device TEXT NOT NULL,
  nickname TEXT NOT NULL,
  rank_title TEXT NOT NULL,
  score INTEGER NOT NULL,
  hours INTEGER NOT NULL,
  wrong_cities INTEGER NOT NULL,
  city TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS scores_rank ON scores (created_at, score DESC);
