// Entrada do Cloudflare Worker: liga a API (api.ts) ao D1 e ao Durable
// Object do contador de online. Só este arquivo depende do runtime do
// Cloudflare — o resto é testado com Node puro.

import { DurableObject } from "cloudflare:workers";
import { handle, newSeed } from "./api.ts";
import { PresenceCounter } from "./presence.ts";
import { D1Store } from "./store.ts";
import { TtlCache } from "./ttlcache.ts";
import { LEADERBOARD_SIZE, WEEK_MS } from "./api.ts";
import type { ScoreRow } from "./store.ts";

// Ranking lido do D1 no máximo uma vez a cada 30 s por período (spec 010).
const LEADERBOARD_TTL_MS = 30_000;

export interface Env {
  DB: D1Database;
  PRESENCE: DurableObjectNamespace<Presence>;
  // Segredo pra o hash de IP (limite de partidas) não ser revertível por força
  // bruta; o IP em si nunca é guardado.
  IP_SALT: string;
  // Rate limiting do próprio Workers (spec 010, RF66); ausente em dev local.
  LIMITER?: { limit(options: { key: string }): Promise<{ success: boolean }> };
}

export class Presence extends DurableObject<Env> {
  private counter = new PresenceCounter();
  private board = new TtlCache<ScoreRow[]>(LEADERBOARD_TTL_MS);

  beat(session: string, ipKey: string): { online: number; interval: number } {
    return this.counter.beat(session, Date.now(), ipKey);
  }

  count(): number {
    return this.counter.count(Date.now());
  }

  // Instância única e global: o cache vale pra todo o tráfego, e o D1 é lido
  // no máximo 2 vezes a cada 30 s (semana e geral), venha o que vier.
  leaderboard(period: "week" | "all"): Promise<ScoreRow[]> {
    const now = Date.now();
    return this.board.get(period, now, () => new D1Store(this.env.DB).top(period === "all" ? 0 : now - WEEK_MS, LEADERBOARD_SIZE));
  }
}

function hex(bytes: ArrayBuffer | Uint8Array): string {
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const presence = env.PRESENCE.get(env.PRESENCE.idFromName("global"));
    return handle(req, {
      store: new D1Store(env.DB),
      presenceBeat: (session, ipKey) => presence.beat(session, ipKey),
      presenceCount: () => presence.count(),
      now: () => Date.now(),
      randomSeed: () => newSeed(() => crypto.getRandomValues(new Uint32Array(1))[0] / 0x100000000),
      newId: () => hex(crypto.getRandomValues(new Uint8Array(16))),
      // rate limiting nativo: aceito no plano grátis, mas permissivo (no
      // teste em produção deixou passar ~170 req/min por IP) — barreira
      // extra, não a principal (spec 010)
      limit: env.LIMITER ? async (key) => (await (env.LIMITER as NonNullable<Env["LIMITER"]>).limit({ key })).success : undefined,
      leaderboardRows: (period) => presence.leaderboard(period),
      // Sal muda por dia: o mesmo IP não é ligável entre dias.
      ipHash: async (ip) => {
        const day = new Date().toISOString().slice(0, 10);
        const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${env.IP_SALT}:${day}:${ip}`));
        return hex(digest).slice(0, 32);
      },
    });
  },
} satisfies ExportedHandler<Env>;
