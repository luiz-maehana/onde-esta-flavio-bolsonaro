// Rotas da API (spec 006-B). Sem dependência do runtime do Cloudflare: o
// worker.ts injeta D1/Durable Object; os testes injetam versões em memória.
//
// Antitrapaça: o servidor sorteia a semente (start) e, no fim (finish),
// refaz o caso inteiro a partir das ações. O cliente nunca informa
// desfecho nem pontos.

import { configForRank, replay, score as computeScore, Outcome, MAX_ACTIONS } from "./engine/case.ts";
import { flavor } from "./engine/data.ts";
import { sanitizeNickname } from "./nickname.ts";
import type { Store } from "./store.ts";

export const ALLOWED_ORIGINS = ["https://luiz-maehana.github.io"];
export const MAX_BODY = 64 * 1024;
export const RUN_TTL_MS = 7 * 24 * 3600 * 1000;
export const RATE_WINDOW_MS = 3600 * 1000;
export const MAX_RUNS_PER_DEVICE = 20;
export const MAX_RUNS_PER_IP = 60;
export const LEADERBOARD_SIZE = 50;
export const WEEK_MS = 7 * 24 * 3600 * 1000;
const MAX_SEED = 2147483647;

const ID_RE = /^[a-f0-9]{32}$/;

export type Deps = {
  store: Store;
  presenceBeat: (session: string) => Promise<{ online: number; interval: number }>;
  presenceCount: () => Promise<number>;
  now: () => number;
  randomSeed: () => number;
  newId: () => string;
  ipHash: (ip: string) => Promise<string>;
};

export async function handle(req: Request, deps: Deps): Promise<Response> {
  const origin = req.headers.get("Origin");
  // Navegador de outro site: recusado. Sem Origin (o .exe, curl): permitido.
  if (origin !== null && !ALLOWED_ORIGINS.includes(origin)) {
    return json({ error: "origin" }, 403, null);
  }
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors(origin) });

  const url = new URL(req.url);
  try {
    if (req.method === "GET") {
      if (url.pathname === "/health") return json({ ok: true }, 200, origin);
      if (url.pathname === "/online") return json({ online: await deps.presenceCount() }, 200, origin);
      if (url.pathname === "/leaderboard") return await leaderboard(url, deps, origin);
    }
    if (req.method === "POST") {
      const body = await readJson(req);
      if (body === null) return json({ error: "body" }, 400, origin);
      if (url.pathname === "/presence") return await presence(body, deps, origin);
      if (url.pathname === "/runs/start") return await start(req, body, deps, origin);
      if (url.pathname === "/runs/finish") return await finish(body, deps, origin);
      if (url.pathname === "/runs/publish") return await publish(body, deps, origin);
    }
    return json({ error: "not_found" }, 404, origin);
  } catch (e) {
    console.error(e);
    return json({ error: "internal" }, 500, origin);
  }
}

// --- Rotas -------------------------------------------------------------------

async function presence(body: Record<string, unknown>, deps: Deps, origin: string | null): Promise<Response> {
  if (!isId(body.session)) return json({ error: "session" }, 400, origin);
  // online + intervalo do próximo sinal (freio do orçamento grátis, presence.ts)
  return json(await deps.presenceBeat(body.session as string), 200, origin);
}

async function start(req: Request, body: Record<string, unknown>, deps: Deps, origin: string | null): Promise<Response> {
  if (!isId(body.device)) return json({ error: "device" }, 400, origin);
  const rank = body.rank;
  if (typeof rank !== "number" || !Number.isInteger(rank) || rank < 0 || rank >= flavor.ranks.length) {
    return json({ error: "rank" }, 400, origin);
  }
  const device = body.device as string;
  const now = deps.now();
  const ipHash = await deps.ipHash(req.headers.get("CF-Connecting-IP") ?? "");
  const recent = await deps.store.countRunsSince(device, ipHash, now - RATE_WINDOW_MS);
  if (recent.device >= MAX_RUNS_PER_DEVICE || recent.ip >= MAX_RUNS_PER_IP) {
    return json({ error: "rate_limited" }, 429, origin);
  }
  const config = configForRank(rank);
  const seed = deps.randomSeed();
  const id = deps.newId();
  await deps.store.createRun({
    id, device, ip_hash: ipHash, seed, rank_index: rank, config: JSON.stringify(config), created_at: now,
    finished_at: null, outcome: null, score: null, hours: null, wrong_cities: null, city: null,
  });
  return json({ run_id: id, seed, config }, 200, origin);
}

async function finish(body: Record<string, unknown>, deps: Deps, origin: string | null): Promise<Response> {
  if (!isId(body.run_id) || !isId(body.device)) return json({ error: "ids" }, 400, origin);
  if (!Array.isArray(body.actions) || body.actions.length > MAX_ACTIONS) return json({ error: "actions" }, 400, origin);
  const now = deps.now();
  const run = await deps.store.getRun(body.run_id as string);
  if (!run || run.device !== body.device) return json({ error: "run" }, 404, origin);
  if (run.finished_at !== null) return json({ error: "already_finished" }, 409, origin);
  if (now - run.created_at > RUN_TTL_MS) return json({ error: "expired" }, 410, origin);

  const state = replay(run.seed, JSON.parse(run.config), body.actions);
  if (!state || !state.isOver()) return json({ error: "invalid_actions" }, 422, origin);
  const points = computeScore(state, run.rank_index);
  const closed = await deps.store.finishRun(run.id, {
    finished_at: now, outcome: state.outcome, score: points, hours: state.hoursUsed(),
    wrong_cities: state.wrongCities, city: state.currentCity,
  });
  if (!closed) return json({ error: "already_finished" }, 409, origin);

  let published = false;
  let position: number | null = null;
  if (body.publish === true && state.outcome === Outcome.WIN && body.dry_run !== true) {
    position = await insertScore(deps, { ...run, finished_at: now, score: points, hours: state.hoursUsed(), wrong_cities: state.wrongCities, city: state.currentCity }, body.nickname);
    published = position !== null;
  }
  return json({ outcome: state.outcome, score: points, published, position }, 200, origin);
}

// Publica depois (o jogador aceitou entrar no ranking ao fim do 1º caso).
async function publish(body: Record<string, unknown>, deps: Deps, origin: string | null): Promise<Response> {
  if (!isId(body.run_id) || !isId(body.device)) return json({ error: "ids" }, 400, origin);
  const run = await deps.store.getRun(body.run_id as string);
  if (!run || run.device !== body.device) return json({ error: "run" }, 404, origin);
  if (run.outcome !== Outcome.WIN || run.score === null) return json({ error: "not_won" }, 409, origin);
  if (deps.now() - run.created_at > RUN_TTL_MS) return json({ error: "expired" }, 410, origin);
  const position = await insertScore(deps, run, body.nickname);
  return json({ published: position !== null, position }, 200, origin);
}

async function insertScore(deps: Deps, run: { id: string; device: string; rank_index: number; score: number | null; hours: number | null; wrong_cities: number | null; city: string | null; finished_at: number | null }, nickname: unknown): Promise<number | null> {
  const createdAt = run.finished_at ?? deps.now();
  const ok = await deps.store.insertScore({
    run_id: run.id, device: run.device, nickname: sanitizeNickname(nickname),
    rank_title: flavor.ranks[run.rank_index].title, score: run.score ?? 0, hours: run.hours ?? 0,
    wrong_cities: run.wrong_cities ?? 0, city: run.city ?? "", created_at: createdAt,
  });
  if (!ok) return null;
  return await deps.store.position(run.score ?? 0, createdAt, createdAt - WEEK_MS, run.device);
}

async function leaderboard(url: URL, deps: Deps, origin: string | null): Promise<Response> {
  const period = url.searchParams.get("period") === "all" ? "all" : "week";
  const since = period === "all" ? 0 : deps.now() - WEEK_MS;
  const device = url.searchParams.get("device");
  const rows = await deps.store.top(since, LEADERBOARD_SIZE);
  const entries = rows.map((r, i) => ({
    // rank: índice do cargo, pro jogo mostrar o título no idioma do jogador
    // (spec 008); rank_title (português) fica pra versões antigas
    position: i + 1, nickname: r.nickname, rank_title: r.rank_title, rank: flavor.ranks.findIndex((k) => k.title === r.rank_title), score: r.score,
    hours: r.hours, wrong_cities: r.wrong_cities, city: r.city, created_at: r.created_at,
    is_you: isId(device) && r.device === device,
  }));
  return json({ period, entries }, 200, origin, 30);
}

// --- Utilidades ------------------------------------------------------------------

function isId(v: unknown): boolean {
  return typeof v === "string" && ID_RE.test(v);
}

async function readJson(req: Request): Promise<Record<string, unknown> | null> {
  const len = Number(req.headers.get("Content-Length") ?? "0");
  if (len > MAX_BODY) return null;
  const text = await req.text();
  if (text.length > MAX_BODY) return null;
  try {
    const v = JSON.parse(text);
    return v !== null && typeof v === "object" && !Array.isArray(v) ? v : null;
  } catch {
    return null;
  }
}

function cors(origin: string | null): Record<string, string> {
  if (origin === null) return {};
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
}

function json(data: unknown, status: number, origin: string | null, cacheSeconds = 0): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": cacheSeconds > 0 ? `public, max-age=${cacheSeconds}` : "no-store",
      "X-Content-Type-Options": "nosniff",
      ...cors(origin),
    },
  });
}

export function newSeed(random: () => number): number {
  return 1 + Math.floor(random() * MAX_SEED);
}
