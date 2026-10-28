// Testes da API com armazenamento em memória e relógio falso: rotas, CORS,
// limites, antitrapaça (replay no servidor) e ranking.
import { test } from "node:test";
import assert from "node:assert/strict";
import { handle, deviceHash, rankForWins, MAX_RUNS_PER_DEVICE, RUN_TTL_MS, WEEK_MS, type Deps } from "../src/api.ts";
import { MIN_RUN_SECONDS } from "../src/plausibility.ts";
import { MAX_SESSIONS_PER_IP } from "../src/presence.ts";
import { TtlCache } from "../src/ttlcache.ts";
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
    presenceBeat: async (s, ip) => presence.beat(s, clock.t, ip),
    presenceCount: async () => presence.count(clock.t),
    now: () => clock.t,
    randomSeed: () => seedSeq++,
    newId: () => (seq++).toString(16).padStart(32, "0"),
    ipHash: async (ip) => `ip-${ip}`,
  };
  const call = async (method: string, path: string, body?: unknown, headers: Record<string, string> = {}) => {
    const init: RequestInit = { method, headers: { Origin: ORIGIN, "CF-Connecting-IP": "1.2.3.4", ...headers } };
    if (body !== undefined) init.body = typeof body === "string" ? body : JSON.stringify(body);
    // partida de gente leva tempo: cada fim de partida acontece 15 min depois
    if (path === "/runs/finish") clock.t += 15 * 60_000;
    const res = await handle(new Request("https://api.test" + path, init), deps);
    const text = await res.text();
    return { status: res.status, headers: res.headers, data: text ? JSON.parse(text) : null };
  };
  return { store, clock, call, deps };
}

// Joga o caso com perfeição a partir da semente/configuração do servidor.
// Joga como gente (spec 010): investiga os locais de cada cidade antes de
// viajar e só emite a pauta depois de ouvir as características.
function perfectActions(seed: number, config: Config, wrongDetour = false): string[][] {
  const s = generate(new GodotRng(seed), config);
  let detoured = false;
  while (!s.isFinalStop()) {
    for (const loc of s.locationsHere()) s.investigate(loc);
    if (wrongDetour && !detoured) {
      detoured = true;
      const wrong = s.travelOptions().find((c) => c !== s.route[s.stopIndex + 1]) as string;
      s.travel(wrong);
      s.travel(s.route[s.stopIndex]);
    }
    s.travel(s.route[s.stopIndex + 1]);
  }
  s.setPauta(s.disguise.id);
  s.investigate(s.locationsHere()[s.hideoutSlot]);
  assert.equal(s.outcome, Outcome.WIN);
  return s.actions;
}

// O robô da auditoria (spec 010): lê a solução do caso, não investiga nada.
function botActions(seed: number, config: Config): string[][] {
  const s = generate(new GodotRng(seed), config);
  const acts: string[][] = [["p", s.disguise.id]];
  for (let i = 1; i < s.route.length; i++) acts.push(["t", s.route[i]]);
  for (let i = 1; i < s.route.length; i++) s.travel(s.route[i]);
  acts.push(["i", s.locationsHere()[s.hideoutSlot]]);
  return acts;
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

test("ranking: uma linha por jogador, com o melhor resultado", async () => {
  const { call, clock } = setup();
  // A vence 3 casos (um com desvio, pontuação menor); B vence 1
  const scores: number[] = [];
  for (const clean of [true, false, true]) {
    const r = await startRun(call, DEV_A);
    const fin = await call("POST", "/runs/finish", { run_id: r.run_id, device: DEV_A, actions: perfectActions(r.seed, r.config, !clean), nickname: "Ana", publish: true });
    assert.equal(fin.data.published, true);
    scores.push(fin.data.score);
    clock.t += 60_000;
  }
  const rb = await startRun(call, DEV_B);
  const finB = await call("POST", "/runs/finish", { run_id: rb.run_id, device: DEV_B, actions: perfectActions(rb.seed, rb.config), nickname: "Bia", publish: true });
  for (const period of ["week", "all"]) {
    const board = await call("GET", `/leaderboard?period=${period}&device=${DEV_A}`);
    assert.equal(board.data.entries.length, 2, "uma linha por aparelho");
    const mine = board.data.entries.filter((e: { is_you: boolean }) => e.is_you);
    assert.equal(mine.length, 1);
    assert.equal(mine[0].score, Math.max(...scores), "fica o melhor resultado");
    assert.equal(mine[0].rank, 0, "índice do cargo pro jogo traduzir (spec 008)");
    assert.deepEqual(board.data.entries.map((e: { position: number }) => e.position), [1, 2]);
  }
  // posição de B conta só o melhor de cada outro aparelho
  const expected = Math.max(...scores) > finB.data.score || (Math.max(...scores) === finB.data.score) ? 2 : 1;
  assert.equal(finB.data.position, expected);
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

// --- Spec 007 (S2): API hostil ------------------------------------------------------

test("campos com tipo errado são recusados sem quebrar", async () => {
  const { call } = setup();
  const run = await startRun(call);
  const bodies: unknown[] = [
    { device: 123, rank: 0 }, { device: DEV_A, rank: "0" }, { device: null }, [], "null", "42", "\"texto\"",
  ];
  for (const b of bodies) {
    const r = await call("POST", "/runs/start", b);
    assert.ok(r.status >= 400 && r.status < 500, `start com ${JSON.stringify(b)} deu ${r.status}`);
  }
  const finishes: unknown[] = [
    { run_id: run.run_id, device: DEV_A, actions: "i,x" }, { run_id: run.run_id, device: DEV_A, actions: { 0: ["i"] } },
    { run_id: run.run_id, device: DEV_A, actions: [[1, 2]] }, { run_id: run.run_id, device: DEV_A, actions: [null] },
    { run_id: 7, device: DEV_A, actions: [] }, { run_id: run.run_id, device: DEV_A, actions: [], publish: "sim", nickname: { a: 1 } },
  ];
  for (const b of finishes) {
    const r = await call("POST", "/runs/finish", b);
    assert.ok(r.status >= 400 && r.status < 500, `finish com ${JSON.stringify(b)} deu ${r.status}`);
  }
  // nada disso queimou a partida: o caso legítimo ainda fecha
  const ok = await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_A, actions: perfectActions(run.seed, run.config) });
  assert.equal(ok.status, 200);
});

test("ação depois do fim do caso é recusada (mesma regra do Godot)", async () => {
  const { call } = setup();
  const run = await startRun(call);
  const actions = perfectActions(run.seed, run.config);
  for (const extra of [["d", "hat", ""], ["p", "turista"], ["i", "banco"]]) {
    const r = await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_A, actions: [...actions, extra] });
    assert.equal(r.status, 422, `ação ${extra[0]} depois do fim aceita`);
  }
});

test("dois finish ao mesmo tempo: só um conta", async () => {
  const { call, store } = setup();
  const run = await startRun(call);
  const body = { run_id: run.run_id, device: DEV_A, actions: perfectActions(run.seed, run.config), nickname: "Ana", publish: true };
  const results = await Promise.all([call("POST", "/runs/finish", body), call("POST", "/runs/finish", body)]);
  assert.deepEqual(results.map((r) => r.status).sort(), [200, 409]);
  assert.equal(store.scores.length, 1);
});

test("apelidos com controle, direção do texto e unicode", () => {
  const cases: [string, (s: string) => boolean][] = [
    ["Ana\nFuro", (s) => s === "Ana Furo"],
    ["‮oruf ana", (s) => !s.includes("‮")],
    ["Ana​​Furo", (s) => !s.includes("​")],
    ["\u0000\u0001\u007F", (s) => s === ANONYMOUS],
    ["José Ação", (s) => s === "José Ação"],
    ["José", (s) => s === "José"],
    ["W".repeat(40), (s) => s.length <= 18],
  ];
  for (const [input, ok] of cases) {
    const out = sanitizeNickname(input);
    assert.ok(ok(out), `apelido ${JSON.stringify(input)} virou ${JSON.stringify(out)}`);
  }
});

test("virada da semana do ranking", async () => {
  const { call, clock } = setup();
  const run = await startRun(call);
  await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_A, actions: perfectActions(run.seed, run.config), nickname: "Ana", publish: true });
  clock.t += WEEK_MS - 1;
  assert.equal((await call("GET", "/leaderboard?period=week")).data.entries.length, 1, "ainda na semana");
  clock.t += 2;
  assert.equal((await call("GET", "/leaderboard?period=week")).data.entries.length, 0, "saiu da semana");
  assert.equal((await call("GET", "/leaderboard?period=all")).data.entries.length, 1, "continua no geral");
});


// --- Spec 010: segurança do ranking ------------------------------------------------

test("robô que lê a solução: partida conta, mas não entra no ranking", async () => {
  const { call, store } = setup();
  const run = await startRun(call);
  const r = await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_A, actions: botActions(run.seed, run.config), nickname: "Bot", publish: true });
  assert.equal(r.status, 200);
  assert.equal(r.data.outcome, Outcome.WIN);
  assert.equal(r.data.published, false);
  assert.ok(r.data.flag, "partida marcada");
  assert.equal(store.scores.length, 0);
  // e nem publicando depois
  const pub = await call("POST", "/runs/publish", { run_id: run.run_id, device: DEV_A, nickname: "Bot" });
  assert.equal(pub.data.published, false);
});

test("partida rápida demais não entra no ranking", async () => {
  const { call, clock, deps } = setup();
  const run = await startRun(call);
  const actions = perfectActions(run.seed, run.config);
  // finish no mesmo instante do start (sem os 15 min do wrapper)
  clock.t -= 15 * 60_000 - (MIN_RUN_SECONDS - 5) * 1000;
  const res = await handle(new Request("https://api.test/runs/finish", {
    method: "POST", headers: { Origin: ORIGIN }, body: JSON.stringify({ run_id: run.run_id, device: DEV_A, actions, publish: true }),
  }), deps);
  const data = await res.json() as { published: boolean; flag: string };
  assert.equal(data.published, false);
  assert.equal(data.flag, "too_fast");
});

test("cargo pedido acima das vitórias registradas cai pro merecido", async () => {
  const { call } = setup();
  const r = await startRun(call, DEV_A, 4);
  assert.equal(r.config.route_len, 4, "sem vitórias: Estagiário");
  assert.equal(rankForWins(0), 0);
  assert.equal(rankForWins(1), 1);
  assert.equal(rankForWins(99), 4);
  // ganha 1 caso: passa a poder Repórter Júnior
  await call("POST", "/runs/finish", { run_id: r.run_id, device: DEV_A, actions: perfectActions(r.seed, r.config) });
  const next = await call("POST", "/runs/start", { device: DEV_A, rank: 4 });
  assert.equal(next.data.rank, 1);
});

test("limite por IP devolve 429 e não deixa passar", async () => {
  const { deps } = setup();
  let calls = 0;
  deps.limit = async () => ++calls <= 3;
  const req = () => handle(new Request("https://api.test/online", { headers: { Origin: ORIGIN } }), deps);
  for (let i = 0; i < 3; i++) assert.equal((await req()).status, 200);
  assert.equal((await req()).status, 429);
  // /health nunca é limitado
  assert.equal((await handle(new Request("https://api.test/health"), deps)).status, 200);
});

test("contador: um IP soma no máximo algumas sessões", async () => {
  const { call } = setup();
  for (let i = 0; i < MAX_SESSIONS_PER_IP + 5; i++) {
    await call("POST", "/presence", { session: i.toString(16).padStart(32, "0") });
  }
  assert.equal((await call("GET", "/online")).data.online, MAX_SESSIONS_PER_IP);
  // outro IP ainda conta
  await call("POST", "/presence", { session: "f".repeat(32) }, { "CF-Connecting-IP": "9.9.9.9" });
  assert.equal((await call("GET", "/online")).data.online, MAX_SESSIONS_PER_IP + 1);
});

test("apelidos: outro alfabeto e nomes reservados viram anônimo", () => {
  // cirílico "р" no lugar do "p": a letra estrangeira some, o palavrão não passa
  assert.ok(!sanitizeNickname("рuta").includes("р") && sanitizeNickname("рuta") !== "рuta");
  assert.equal(sanitizeNickname("Flavio Bolsonaro"), ANONYMOUS);
  assert.equal(sanitizeNickname("Pablo Marçal 2"), ANONYMOUS);
  assert.equal(sanitizeNickname("Reporter Anonimo"), ANONYMOUS);
  assert.equal(sanitizeNickname("Ana Bolsonaro"), "Ana Bolsonaro", "sobrenome sozinho não é reservado");
  assert.equal(sanitizeNickname("José Ação"), "José Ação", "acentos latinos continuam");
});

test("corpo grande sem Content-Length é recusado", async () => {
  const { deps } = setup();
  const big = new ReadableStream({
    start(c) {
      for (let i = 0; i < 80; i++) c.enqueue(new TextEncoder().encode("x".repeat(1024)));
      c.close();
    },
  });
  const res = await handle(new Request("https://api.test/presence", { method: "POST", headers: { Origin: ORIGIN }, body: big, duplex: "half" } as RequestInit), deps);
  assert.equal(res.status, 400);
});

test("ranking marca você pelo hash do aparelho (e ainda pelo id antigo)", async () => {
  const { call } = setup();
  const run = await startRun(call);
  await call("POST", "/runs/finish", { run_id: run.run_id, device: DEV_A, actions: perfectActions(run.seed, run.config), nickname: "Ana", publish: true });
  const byHash = await call("GET", "/leaderboard?you=" + (await deviceHash(DEV_A)));
  assert.equal(byHash.data.entries[0].is_you, true);
  const byId = await call("GET", "/leaderboard?device=" + DEV_A);
  assert.equal(byId.data.entries[0].is_you, true);
  const other = await call("GET", "/leaderboard?you=" + (await deviceHash(DEV_B)));
  assert.equal(other.data.entries[0].is_you, false);
});

test("cache do ranking: uma leitura por período dentro da validade", async () => {
  const cache = new TtlCache<number>(30_000);
  let loads = 0;
  const load = async () => ++loads;
  const t0 = 1_000_000;
  // consultas simultâneas com o cache vazio esperam a mesma leitura
  const [a, b] = await Promise.all([cache.get("week", t0, load), cache.get("week", t0 + 1, load)]);
  assert.equal(a, 1);
  assert.equal(b, 1);
  assert.equal(await cache.get("week", t0 + 29_000, load), 1, "ainda válido");
  assert.equal(await cache.get("all", t0 + 29_000, load), 2, "outro período lê à parte");
  assert.equal(await cache.get("week", t0 + 30_000, load), 3, "venceu: lê de novo");
  assert.equal(loads, 3);
  // leitura que falha não fica guardada
  await assert.rejects(cache.get("x", t0, async () => { throw new Error("D1 fora"); }));
  assert.equal(await cache.get("x", t0 + 1, async () => 42), 42);
});

test("ranking usa as linhas em cache quando o servidor oferece", async () => {
  const { call, deps } = setup();
  let asked = 0;
  deps.leaderboardRows = async () => {
    asked++;
    return [{ run_id: "r", device: DEV_A, nickname: "Cache", rank_title: "Repórter", score: 1, hours: 1, wrong_cities: 0, city: "rio", created_at: 0 }];
  };
  const r = await call("GET", "/leaderboard?you=" + (await deviceHash(DEV_A)));
  assert.equal(asked, 1);
  assert.equal(r.data.entries[0].nickname, "Cache");
  assert.equal(r.data.entries[0].is_you, true);
});
