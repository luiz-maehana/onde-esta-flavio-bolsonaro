// Teste de fumaça contra a API publicada: saúde, contador e um caso inteiro
// (start -> jogada perfeita -> finish em dry_run, que não grava no ranking).
// Uso: node scripts/smoke.ts https://onde-esta-flavio-api.<sub>.workers.dev
import { generate, type Config } from "../src/engine/case.ts";
import { GodotRng } from "../src/engine/rng.ts";

const base = process.argv[2];
if (!base) throw new Error("informe a URL da API");
const device = "c1".repeat(16);

async function call(method: string, path: string, body?: unknown) {
  const res = await fetch(base + path, { method, body: body ? JSON.stringify(body) : undefined, headers: { "Content-Type": "application/json" } });
  const data = await res.json();
  if (!res.ok) throw new Error(`${method} ${path}: ${res.status} ${JSON.stringify(data)}`);
  return data;
}

console.log("health:", await call("GET", "/health"));
console.log("presence:", await call("POST", "/presence", { session: "d2".repeat(16) }));
const run = (await call("POST", "/runs/start", { device, rank: 0 })) as { run_id: string; seed: number; config: Config };
const s = generate(new GodotRng(run.seed), run.config);
s.setPauta(s.disguise.id);
while (!s.isFinalStop()) {
  s.investigate(s.locationsHere()[0]);
  s.travel(s.route[s.stopIndex + 1]);
}
s.investigate(s.locationsHere()[s.hideoutSlot]);
const fin = await call("POST", "/runs/finish", { run_id: run.run_id, device, actions: s.actions, dry_run: true, publish: true });
console.log("finish:", fin);
if (fin.outcome !== 1 || fin.published !== false) throw new Error("caso de fumaça deveria vencer sem publicar");
console.log("leaderboard:", (await call("GET", "/leaderboard")).entries.length, "entradas");
console.log("API OK");
