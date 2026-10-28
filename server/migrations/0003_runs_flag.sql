-- Spec 010 (RF64): partida legal mas implausível (rápida demais, viagem ou
-- pauta "às cegas") fica marcada e não vai pro ranking.
ALTER TABLE runs ADD COLUMN flag TEXT;
CREATE INDEX IF NOT EXISTS runs_device_outcome ON runs (device, outcome);
