-- Ranking mostra o melhor resultado de cada aparelho (não uma linha por caso).
CREATE INDEX IF NOT EXISTS scores_device ON scores (device, created_at, score DESC);
