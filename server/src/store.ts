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
  /** Spec 010: motivo de não publicar (partida implausível); null = ok. */
  flag?: string | null;
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
  finishRun(id: string, fields: Pick<Run, "finished_at" | "outcome" | "score" | "hours" | "wrong_cities" | "city" | "flag">): Promise<boolean>;
  /** Vitórias do aparelho registradas no servidor (cargo, spec 010). */
  winsOf(device: string): Promise<number>;
  insertScore(row: ScoreRow): Promise<boolean>;
  hasScore(runId: string): Promise<boolean>;
  /** Melhor resultado de cada aparelho no período (empate: o mais antigo). */
  top(since: number, limit: number): Promise<ScoreRow[]>;
  /** Lugar desse resultado contra o melhor de cada um dos outros aparelhos. */
  position(score: number, createdAt: number, since: number, device: string): Promise<number>;
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
  async finishRun(id: string, f: Pick<Run, "finished_at" | "outcome" | "score" | "hours" | "wrong_cities" | "city" | "flag">): Promise<boolean> {
    const res = await this.db
      .prepare("UPDATE runs SET finished_at = ?, outcome = ?, score = ?, hours = ?, wrong_cities = ?, city = ?, flag = ? WHERE id = ? AND finished_at IS NULL")
      .bind(f.finished_at, f.outcome, f.score, f.hours, f.wrong_cities, f.city, f.flag ?? null, id)
      .run();
    return (res.meta.changes ?? 0) > 0;
  }

  async winsOf(device: string): Promise<number> {
    const row = await this.db
      .prepare("SELECT COUNT(*) AS n FROM runs WHERE device = ? AND outcome = 1")
      .bind(device)
      .first<{ n: number }>();
    return row?.n ?? 0;
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
      .prepare(
        "SELECT s.* FROM scores s WHERE s.created_at >= ?1 AND NOT EXISTS (" +
          "SELECT 1 FROM scores t WHERE t.device = s.device AND t.created_at >= ?1 AND " +
          "(t.score > s.score OR (t.score = s.score AND (t.created_at < s.created_at OR (t.created_at = s.created_at AND t.run_id < s.run_id))))" +
          ") ORDER BY s.score DESC, s.created_at ASC LIMIT ?2",
      )
      .bind(since, limit)
      .all<ScoreRow>();
    return res.results ?? [];
  }

  async position(score: number, createdAt: number, since: number, device: string): Promise<number> {
    const row = await this.db
      .prepare("SELECT COUNT(DISTINCT device) AS n FROM scores WHERE created_at >= ? AND device != ? AND (score > ? OR (score = ? AND created_at < ?))")
      .bind(since, device, score, score, createdAt)
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

  async finishRun(id: string, f: Pick<Run, "finished_at" | "outcome" | "score" | "hours" | "wrong_cities" | "city" | "flag">): Promise<boolean> {
    const r = this.runs.get(id);
    if (!r || r.finished_at !== null) return false;
    Object.assign(r, f);
    return true;
  }

  async winsOf(device: string): Promise<number> {
    let n = 0;
    for (const r of this.runs.values()) if (r.device === device && r.outcome === 1) n++;
    return n;
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
    const best = new Map<string, ScoreRow>();
    for (const s of this.scores.filter((x) => x.created_at >= since).sort(byRank)) {
      if (!best.has(s.device)) best.set(s.device, s);
    }
    return [...best.values()].sort(byRank).slice(0, limit);
  }

  async position(score: number, createdAt: number, since: number, device: string): Promise<number> {
    const ahead = new Set(
      this.scores
        .filter((s) => s.created_at >= since && s.device !== device && (s.score > score || (s.score === score && s.created_at < createdAt)))
        .map((s) => s.device),
    );
    return 1 + ahead.size;
  }
}

function byRank(a: ScoreRow, b: ScoreRow): number {
  return b.score - a.score || a.created_at - b.created_at || (a.run_id < b.run_id ? -1 : 1);
}
