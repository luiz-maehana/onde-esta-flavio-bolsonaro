// Deploy: garante que o banco D1 existe (cria na primeira vez) e grava o id
// dele no wrangler.jsonc da máquina de build. Idempotente.
import { execSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";

const NAME = "onde-esta-flavio";
const run = (cmd) => execSync(cmd, { encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] });

let db = JSON.parse(run("npx wrangler d1 list --json")).find((d) => d.name === NAME);
if (!db) {
  console.log(`criando banco D1 ${NAME}...`);
  run(`npx wrangler d1 create ${NAME}`);
  db = JSON.parse(run("npx wrangler d1 list --json")).find((d) => d.name === NAME);
}
if (!db) throw new Error("não consegui criar/achar o banco D1");
const id = db.uuid ?? db.database_id ?? db.id;
const cfg = readFileSync("wrangler.jsonc", "utf8").replace("00000000-0000-0000-0000-000000000000", id);
writeFileSync("wrangler.jsonc", cfg);
console.log(`banco D1 ${NAME}: ${id}`);
