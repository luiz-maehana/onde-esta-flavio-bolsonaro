// Onde ficam partidas e pontuações. A API (api.ts) só conhece esta
// interface: em produção é o D1; nos testes, a versão em memória.

export type Run = {
  id: string;
  device: string;
  ip_hash: string;
  seed: number;
  rank_index: number;
  config: string;
  created_at: number;
  finished_at: number | null;
  outcome: number | null;
  score: number | null;
  hours: number | null;
  wrong_cities: number | null;
  city: string | null;
};

export type ScoreRow = {
  run_id: string;
  device: string;
  nickname: string;
  rank_title: string;
  score: number;
  hours: number;
  wrong_cities: number;
  city: string;
  created_at: number;
};

export interface Store {
  createRun(run: Run): Promise<void>;
  getRun(id: string): Promise<Run | null>;
  countRunsSince(device: string, ipHash: string, since: number): Promise<{ device: number; ip: number }>;
  finishRun(id: string, fields: Pick<Run, "finished_at" | "outcome" | "score" | "hours" | "wrong_cities" | "city">): Promise<boolean>;
  insertScore(row: ScoreRow): Promise<boolean>;
  hasScore(runId: string): Promise<boolean>;
  top(since: number, limit: number): Promise<ScoreRow[]>;
  position(score: number, createdAt: number, since: number): Promise<number>;
}

// ---------------------------------------------------------------------------

export class D1Store implements Store {
  private db: D1Database;

  constructor(db: D1Database) {
    this.db = db;
  }

  async createRun(r: Run): Promise<void> {
    await this.db
      .prepare("INSERT INTO runs (id, device, ip_hash, seed, rank_index, config, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)")
      .bind(r.id, r.device, r.ip_hash, r.seed, r.rank_index, r.config, r.created_at)
      .run();
  }

  async getRun(id: string): Promise<Run | null> {
    return await this.db.prepare("SELECT * FROM runs WHERE id = ?").bind(id).first<Run>();
  }

  async countRunsSince(device: string, ipHash: string, since: number): Promise<{ device: number; ip: number }> {
    const row = await this.db
      .prepare(
        "SELECT SUM(CASE WHEN device = ? THEN 1 ELSE 0 END) AS d, SUM(CASE WHEN ip_hash = ? THEN 1 ELSE 0 END) AS i FROM runs WHERE created_at >= ? AND (device = ? OR ip_hash = ?)",
      )
      .bind(device, ipHash, since, device, ipHash)
      .first<{ d: number | null; i: number | null }>();
    return { device: row?.d ?? 0, ip: row?.i ?? 0 };
  }

  // Só fecha partida ainda aberta (finished_at IS NULL): uso único.
  async finishRun(id: string, f: Pick<Run, "finished_at" | "outcome" | "score" | "hours" | "wrong_cities" | "city">): Promise<boolean> {
    const res = await this.db
      .prepare("UPDATE runs SET finished_at = ?, outcome = ?, score = ?, hours = ?, wrong_cities = ?, city = ? WHERE id = ? AND finished_at IS NULL")
      .bind(f.finished_at, f.outcome, f.score, f.hours, f.wrong_cities, f.city, id)
      .run();
    return (res.meta.changes ?? 0) > 0;
  }

  async insertScore(s: ScoreRow): Promise<boolean> {
    const res = await this.db
      .prepare(
        "INSERT OR IGNORE INTO scores (run_id, device, nickname, rank_title, score, hours, wrong_cities, city, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
      )
      .bind(s.run_id, s.device, s.nickname, s.rank_title, s.score, s.hours, s.wrong_cities, s.city, s.created_at)
      .run();
    return (res.meta.changes ?? 0) > 0;
  }

  async hasScore(runId: string): Promise<boolean> {
    return (await this.db.prepare("SELECT 1 FROM scores WHERE run_id = ?").bind(runId).first()) !== null;
  }

  async top(since: number, limit: number): Promise<ScoreRow[]> {
    const res = await this.db
      .prepare("SELECT * FROM scores WHERE created_at >= ? ORDER BY score DESC, created_at ASC LIMIT ?")
      .bind(since, limit)
      .all<ScoreRow>();
    return res.results ?? [];
  }

  async position(score: number, createdAt: number, since: number): Promise<number> {
    const row = await this.db
      .prepare("SELECT COUNT(*) AS n FROM scores WHERE created_at >= ? AND (score > ? OR (score = ? AND created_at < ?))")
      .bind(since, score, score, createdAt)
      .first<{ n: number }>();
    return (row?.n ?? 0) + 1;
  }
}

// ---------------------------------------------------------------------------

export class MemoryStore implements Store {
  runs = new Map<string, Run>();
  scores: ScoreRow[] = [];

  async createRun(r: Run): Promise<void> {
    this.runs.set(r.id, { ...r });
  }

  async getRun(id: string): Promise<Run | null> {
    const r = this.runs.get(id);
    return r ? { ...r } : null;
  }

  async countRunsSince(device: string, ipHash: string, since: number): Promise<{ device: number; ip: number }> {
    let d = 0;
    let i = 0;
    for (const r of this.runs.values()) {
      if (r.created_at < since) continue;
      if (r.device === device) d++;
      if (r.ip_hash === ipHash) i++;
    }
    return { device: d, ip: i };
  }

  async finishRun(id: string, f: Pick<Run, "finished_at" | "outcome" | "score" | "hours" | "wrong_cities" | "city">): Promise<boolean> {
    const r = this.runs.get(id);
    if (!r || r.finished_at !== null) return false;
    Object.assign(r, f);
    return true;
  }

  async insertScore(s: ScoreRow): Promise<boolean> {
    if (this.scores.some((x) => x.run_id === s.run_id)) return false;
    this.scores.push({ ...s });
    return true;
  }

  async hasScore(runId: string): Promise<boolean> {
    return this.scores.some((x) => x.run_id === runId);
  }

  async top(since: number, limit: number): Promise<ScoreRow[]> {
    return this.scores
      .filter((s) => s.created_at >= since)
      .sort((a, b) => b.score - a.score || a.created_at - b.created_at)
      .slice(0, limit);
  }

  async position(score: number, createdAt: number, since: number): Promise<number> {
    return 1 + this.scores.filter((s) => s.created_at >= since && (s.score > score || (s.score === score && s.created_at < createdAt))).length;
  }
}
