// Rotas da API (spec 006-B). Sem dependência do runtime do Cloudflare: o
// worker.ts injeta D1/Durable Object; os testes injetam versões em memória.
//
// Antitrapaça: o servidor sorteia a semente (start) e, no fim (finish),
// refaz o caso inteiro a partir das ações. O cliente nunca informa
// desfecho nem pontos.

import { configForRank, replay, score as computeScore, Outcome, MAX_ACTIONS } from "./engine/case.ts";
import { flavor } from "./engine/data.ts";
import { sanitizeNickname } from "./nickname.ts";
import { implausible } from "./plausibility.ts";
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
  presenceBeat: (session: string, ipKey: string) => Promise<{ online: number; interval: number }>;
  presenceCount: () => Promise<number>;
  now: () => number;
  randomSeed: () => number;
  newId: () => string;
  ipHash: (ip: string) => Promise<string>;
  /** Spec 010 (RF66): limite de requisições por chave (hash do IP);
   * false = estourou. Ausente = sem limite (testes antigos, dev local). */
  limit?: (key: string) => Promise<boolean>;
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
    // limite por IP nas rotas que gastam (tudo menos /health)
    if (deps.limit && url.pathname !== "/health") {
      const key = await deps.ipHash(req.headers.get("CF-Connecting-IP") ?? "");
      if (!(await deps.limit(key))) return json({ error: "rate_limited" }, 429, origin);
    }
    if (req.method === "GET") {
      if (url.pathname === "/health") return json({ ok: true }, 200, origin);
      if (url.pathname === "/online") return json({ online: await deps.presenceCount() }, 200, origin);
      if (url.pathname === "/leaderboard") return await leaderboard(url, deps, origin);
    }
    if (req.method === "POST") {
      const body = await readJson(req);
      if (body === null) return json({ error: "body" }, 400, origin);
      if (url.pathname === "/presence") return await presence(req, body, deps, origin);
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

async function presence(req: Request, body: Record<string, unknown>, deps: Deps, origin: string | null): Promise<Response> {
  if (!isId(body.session)) return json({ error: "session" }, 400, origin);
  // online + intervalo do próximo sinal (freio do orçamento grátis, presence.ts);
  // o hash do IP limita quantas sessões um IP soma ao contador (spec 010)
  const ipKey = await deps.ipHash(req.headers.get("CF-Connecting-IP") ?? "");
  return json(await deps.presenceBeat(body.session as string, ipKey), 200, origin);
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
  // Spec 010 (RF65): o cargo vem do jogo, mas não passa do que as vitórias
  // deste aparelho registradas aqui justificam (senão qualquer um se diz
  // Editor-Chefe e ganha pontos de base)
  const earned = rankForWins(await deps.store.winsOf(device));
  const rankIndex = Math.min(rank, earned);
  const config = configForRank(rankIndex);
  const seed = deps.randomSeed();
  const id = deps.newId();
  await deps.store.createRun({
    id, device, ip_hash: ipHash, seed, rank_index: rankIndex, config: JSON.stringify(config), created_at: now,
    finished_at: null, outcome: null, score: null, hours: null, wrong_cities: null, city: null, flag: null,
  });
  return json({ run_id: id, seed, config, rank: rankIndex }, 200, origin);
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
  // Spec 010 (RF64): legal mas implausível conta pro jogador, não pro ranking
  const flag = state.outcome === Outcome.WIN ? implausible(run.seed, JSON.parse(run.config), body.actions as string[][], now - run.created_at) : null;
  const closed = await deps.store.finishRun(run.id, {
    finished_at: now, outcome: state.outcome, score: points, hours: state.hoursUsed(),
    wrong_cities: state.wrongCities, city: state.currentCity, flag,
  });
  if (!closed) return json({ error: "already_finished" }, 409, origin);

  let published = false;
  let position: number | null = null;
  if (body.publish === true && state.outcome === Outcome.WIN && flag === null && body.dry_run !== true) {
    position = await insertScore(deps, { ...run, finished_at: now, score: points, hours: state.hoursUsed(), wrong_cities: state.wrongCities, city: state.currentCity }, body.nickname);
    published = position !== null;
  }
  return json({ outcome: state.outcome, score: points, published, position, flag }, 200, origin);
}

// Publica depois (o jogador aceitou entrar no ranking ao fim do 1º caso).
async function publish(body: Record<string, unknown>, deps: Deps, origin: string | null): Promise<Response> {
  if (!isId(body.run_id) || !isId(body.device)) return json({ error: "ids" }, 400, origin);
  const run = await deps.store.getRun(body.run_id as string);
  if (!run || run.device !== body.device) return json({ error: "run" }, 404, origin);
  if (run.outcome !== Outcome.WIN || run.score === null) return json({ error: "not_won" }, 409, origin);
  if (run.flag) return json({ published: false, position: null, flag: run.flag }, 200, origin);
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
  // Spec 010 (RF70): o jogo manda "you" = hash do id do aparelho (o id em si
  // não vai pra URL nem pra log); "device" (id cru) fica pra versões antigas
  const device = url.searchParams.get("device");
  const you = url.searchParams.get("you");
  const rows = await deps.store.top(since, LEADERBOARD_SIZE);
  const mine = await Promise.all(rows.map(async (r) => (isId(device) && r.device === device) || (isId(you) && (await deviceHash(r.device)) === you)));
  const entries = rows.map((r, i) => ({
    // rank: índice do cargo, pro jogo mostrar o título no idioma do jogador
    // (spec 008); rank_title (português) fica pra versões antigas
    position: i + 1, nickname: r.nickname, rank_title: r.rank_title, rank: flavor.ranks.findIndex((k) => k.title === r.rank_title), score: r.score,
    hours: r.hours, wrong_cities: r.wrong_cities, city: r.city, created_at: r.created_at,
    is_you: mine[i],
  }));
  return json({ period, entries }, 200, origin, 30);
}

// --- Utilidades ------------------------------------------------------------------

function isId(v: unknown): boolean {
  return typeof v === "string" && ID_RE.test(v);
}

// Spec 010 (RF69): lido em partes, parando ao passar do limite — não confia
// no Content-Length (pode faltar ou mentir).
async function readJson(req: Request): Promise<Record<string, unknown> | null> {
  const len = Number(req.headers.get("Content-Length") ?? "0");
  if (len > MAX_BODY) return null;
  if (!req.body) return null;
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_BODY) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let at = 0;
  for (const c of chunks) {
    bytes.set(c, at);
    at += c.byteLength;
  }
  const text = new TextDecoder().decode(bytes);
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

/** Hash do id do aparelho (32 hex), o mesmo que o jogo manda em "you". */
export async function deviceHash(device: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(device));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 32);
}

/** Maior cargo que \`wins\` vitórias justificam (min_cases do flavor.json). */
export function rankForWins(wins: number): number {
  let index = 0;
  flavor.ranks.forEach((r, i) => {
    if (wins >= r.min_cases) index = i;
  });
  return index;
}

export function newSeed(random: () => number): number {
  return 1 + Math.floor(random() * MAX_SEED);
}
