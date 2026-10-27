// Testes da API com armazenamento em memória e relógio falso: rotas, CORS,
// limites, antitrapaça (replay no servidor) e ranking.
import { test } from "node:test";
import assert from "node:assert/strict";
import { handle, MAX_RUNS_PER_DEVICE, RUN_TTL_MS, WEEK_MS, type Deps } from "../src/api.ts";
import { MemoryStore } from "../src/store.ts";
import { PresenceCounter, BEAT_BUDGET, MIN_INTERVAL_S } from "../src/presence.ts";
import { generate, Outcome, type Config } from "../src/engine/case.ts";
import { GodotRng } from "../src/engine/rng.ts";
import { sanitizeNickname, ANONYMOUS } from "../src/nickname.ts";

const ORIGIN = "https://luiz-maehana.github.io";
const DEV_A = "a".repeat(32);
const DEV_B = "b".repeat(32);

function setup() {
  const store = new MemoryStore();
  const presence = new PresenceCounter();
  const clock = { t: 1_800_000_000_000 };
  let seq = 0;
  let seedSeq = 1000;
  const deps: Deps = {
    store,
    presenceBeat: async (s) => presence.beat(s, clock.t),
    presenceCount: async () => presence.count(clock.t),
    now: () => clock.t,
    randomSeed: () => seedSeq++,
    newId: () => (seq++).toString(16).padStart(32, "0"),
    ipHash: async (ip) => `ip-${ip}`,
  };
  const call = async (method: string, path: string, body?: unknown, headers: Record<string, string> = {}) => {
    const init: RequestInit = { method, headers: { Origin: ORIGIN, "CF-Connecting-IP": "1.2.3.4", ...headers } };
    if (body !== undefined) init.body = typeof body === "string" ? body : JSON.stringify(body);
    const res = await handle(new Request("https://api.test" + path, init), deps);
    const text = await res.text();
    return { status: res.status, headers: res.headers, data: text ? JSON.parse(text) : null };
  };
  return { store, clock, call, deps };
}

// Joga o caso com perfeição a partir da semente/configuração do servidor.
function perfectActions(seed: number, config: Config, wrongDetour = false): string[][] {
  const s = generate(new GodotRng(seed), config);
  s.setPauta(s.disguise.id);
  let detoured = false;
  while (!s.isFinalStop()) {
    s.investigate(s.locationsHere()[0]);
    if (wrongDetour && !detoured) {
      detoured = true;
      const wrong = s.travelOptions().find((c) => c !== s.route[s.stopIndex + 1]) as string;
      s.travel(wrong);
      s.travel(s.route[s.stopIndex]);
    }
    s.travel(s.route[s.stopIndex + 1]);
  }
  s.investigate(s.locationsHere()[s.hideoutSlot]);
  assert.equal(s.outcome, Outcome.WIN);
  return s.actions;
}

async function startRun(call: ReturnType<typeof setup>["call"], device = DEV_A, rank = 0) {
  const r = await call("POST", "/runs/start", { device, rank });
  assert.equal(r.status, 200, JSON.stringify(r.data));
  return r.data as { run_id: string; seed: number; config: Config };
}

test("CORS: outro site recusado, site do jogo e .exe (sem Origin) aceitos", async () => {
  const { call } = setup();
  assert.equal((await call("GET", "/health", undefined, { Origin: "https://evil.example" })).status, 403);
  const ok = await call("GET", "/health");
  assert.equal(ok.status, 200);
  assert.equal(ok.headers.get("Access-Control-Allow-Origin"), ORIGIN);
  const { deps } = setup();
  const exe = await handle(new Request("https://api.test/health"), deps);
  assert.equal(exe.status, 200, "sem Origin (exe) é aceito");
  assert.equal(exe.headers.get("Access-Control-Allow-Origin"), null, "sem Origin não devolve CORS");
  const pre = await call("OPTIONS", "/runs/start");
  assert.equal(pre.status, 204);
});

test("contador de online: sessão válida conta, some depois da janela", async () => {
  const { call, clock } = setup();
  assert.equal((await call("POST", "/presence", { session: "x" })).status, 400);
  await call("POST", "/presence", { session: "1".repeat(32) });
  const two = await call("POST", "/presence", { session: "2".repeat(32) });
  assert.equal(two.data.online, 2);
  assert.equal(two.data.interval, MIN_INTERVAL_S, "pouca gente: sinal a cada minuto");
  clock.t += MIN_INTERVAL_S * 2.5 * 1000 + 1;
  assert.equal((await call("GET", "/online")).data.online, 0);
});

test("start: valida aparelho e cargo, limita partidas por hora", async () => {
  const { call } = setup();
  assert.equal((await call("POST", "/runs/start", { device: "curto", rank: 0 })).status, 400);
  assert.equal((await call("POST", "/runs/start", { device: DEV_A, rank: 99 })).status, 400);
  assert.equal((await call("POST", "/runs/start", { device: DEV_A, rank: 1.5 })).status, 400);
  const run = await startRun(call);
  assert.match(run.run_id, /^[a-f0-9]{32}$/);
  assert.equal(run.config.route_len, 4);
  for (let i = 1; i < MAX_RUNS_PER_DEVICE; i++) await startRun(call);
  assert.equal((await call("POST", "/runs/start", { device: DEV_A, rank: 0 })).status, 429);
});

test("finish: caso legítimo vence e pontua; servidor calcula sozinho", async () => {
  const { call } = setup();
  const run = await startRun(call, DEV_A, 2);
  const actions = perfectActions(run.seed, run.config);
  const r = await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_A, actions, nickname: "Ana", publish: true });
  assert.equal(r.status, 200);
  assert.equal(r.data.outcome, Outcome.WIN);
  assert.ok(r.data.score > 0);
  assert.equal(r.data.published, true);
  assert.equal(r.data.position, 1);
});

test("finish: trapaças recusadas", async () => {
  const { call, clock } = setup();
  const run = await startRun(call);
  const actions = perfectActions(run.seed, run.config);
  // ações de outro caso / adulteradas
  const bad = [...actions.slice(0, -1), ["t", "cidade_falsa"]];
  assert.equal((await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_A, actions: bad })).status, 422);
  // caso que não terminou não pontua
  assert.equal((await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_A, actions: actions.slice(0, 2) })).status, 422);
  // outro aparelho não pode fechar a partida
  assert.equal((await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_B, actions })).status, 404);
  // partida inexistente
  assert.equal((await call("POST", "/runs/finish", { run_id: "f".repeat(32), device: DEV_A, actions })).status, 404);
  // uso único
  assert.equal((await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_A, actions })).status, 200);
  assert.equal((await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_A, actions })).status, 409);
  // expirada
  const old = await startRun(call);
  clock.t += RUN_TTL_MS + 1;
  assert.equal((await call("POST", "/runs/finish", { run_id: old.run_id, device: DEV_A, actions: perfectActions(old.seed, old.config) })).status, 410);
  // corpo inválido / grande demais
  assert.equal((await call("POST", "/runs/finish", "{nope")).status, 400);
  assert.equal((await call("POST", "/runs/finish", "x".repeat(70_000))).status, 400);
  assert.equal((await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_A, actions: new Array(2000).fill(["i", "x"]) })).status, 400);
});

test("ranking: publicar depois, ordem, semana, is_you e moderação", async () => {
  const { call, clock } = setup();
  // jogador perfeito (sem erro) e jogador com 1 desvio: o perfeito fica na frente
  const r1 = await startRun(call, DEV_A);
  await call("POST", "/runs/finish", { run_id: r1.run_id, device: DEV_A, actions: perfectActions(r1.seed, r1.config, true), nickname: "porra louca", publish: true });
  const r2 = await startRun(call, DEV_B);
  const fin = await call("POST", "/runs/finish", { run_id: r2.run_id, device: DEV_B, actions: perfectActions(r2.seed, r2.config), publish: false });
  assert.equal(fin.data.published, false);
  const pub = await call("POST", "/runs/publish", { run_id: r2.run_id, device: DEV_B, nickname: "Bia <script>" });
  assert.equal(pub.data.published, true);
  assert.equal((await call("POST", "/runs/publish", { run_id: r2.run_id, device: DEV_B, nickname: "Bia" })).data.published, false);

  const board = await call("GET", `/leaderboard?device=${DEV_B}`);
  assert.equal(board.data.entries.length, 2);
  const names = board.data.entries.map((e: { nickname: string }) => e.nickname);
  assert.ok(names.includes(ANONYMOUS), "apelido ofensivo virou anônimo");
  assert.ok(names.includes("Bia script"), "html removido do apelido");
  assert.ok(board.data.entries[0].score >= board.data.entries[1].score);
  assert.equal(board.data.entries.filter((e: { is_you: boolean }) => e.is_you).length, 1);

  clock.t += WEEK_MS + 1;
  assert.equal((await call("GET", "/leaderboard?period=week")).data.entries.length, 0);
  assert.equal((await call("GET", "/leaderboard?period=all")).data.entries.length, 2);
});

test("dry_run não grava no ranking", async () => {
  const { call, store } = setup();
  const run = await startRun(call);
  const r = await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_A, actions: perfectActions(run.seed, run.config), publish: true, dry_run: true });
  assert.equal(r.data.outcome, Outcome.WIN);
  assert.equal(r.data.published, false);
  assert.equal(store.scores.length, 0);
});

test("apelidos", () => {
  assert.equal(sanitizeNickname("  Ana   Furo  "), "Ana Furo");
  assert.equal(sanitizeNickname("Flávio Ação"), "Flávio Ação");
  assert.equal(sanitizeNickname("x"), ANONYMOUS);
  assert.equal(sanitizeNickname(42), ANONYMOUS);
  assert.equal(sanitizeNickname("P0rr4"), ANONYMOUS);
  assert.equal(sanitizeNickname("vai tnc"), ANONYMOUS);
  assert.equal(sanitizeNickname("Curitibano"), "Curitibano", "'cu' só bloqueia palavra inteira");
  assert.equal(sanitizeNickname("A".repeat(40)).length, 18);
});

test("rota desconhecida", async () => {
  const { call } = setup();
  assert.equal((await call("GET", "/admin")).status, 404);
});

test("freio do plano grátis: intervalo cresce com gente online e com o orçamento gasto", () => {
  const p = new PresenceCounter();
  const t0 = Date.UTC(2026, 9, 27, 0, 0, 0);
  // ~48 pessoas o dia todo cabem com sinal a cada minuto (48 × 1440 ≈ 69 mil)
  let beat = { online: 0, interval: 0 };
  for (let i = 0; i < 40; i++) beat = p.beat(i.toString(16).padStart(32, "0"), t0);
  assert.equal(beat.interval, MIN_INTERVAL_S);
  // 2.000 pessoas o dia todo: intervalo cresce (~42 min) pra caber no orçamento
  for (let i = 40; i < 2000; i++) beat = p.beat(i.toString(16).padStart(32, "0"), t0);
  assert.ok(beat.interval > 30 * 60, `intervalo ${beat.interval}`);
  // dia inteiro simulado com muita gente: o total de sinais cabe no orçamento
  // (+ no máximo 1 sinal por pessoa)
  for (const users of [1000, 5000]) {
    const q = new PresenceCounter();
    let beats = 0;
    const next = new Array(users).fill(t0);
    for (let t = t0; t < t0 + 86_400_000; t += 30_000) {
      for (let u = 0; u < users; u++) {
        if (next[u] <= t) {
          const b = q.beat(u.toString(16).padStart(32, "0"), t);
          beats++;
          next[u] = t + b.interval * 1000;
        }
      }
    }
    assert.ok(beats <= BEAT_BUDGET + users, `${users} pessoas: ${beats} sinais no dia`);
  }
  // orçamento esgotado: próximo sinal só depois da meia-noite UTC
  const full = new PresenceCounter();
  for (let i = 0; i < BEAT_BUDGET; i++) full.beat("f".repeat(32), t0);
  assert.ok(full.interval(10, t0) >= 86_400);
});
