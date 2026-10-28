// Entrada do Cloudflare Worker: liga a API (api.ts) ao D1 e ao Durable
// Object do contador de online. Só este arquivo depende do runtime do
// Cloudflare — o resto é testado com Node puro.

import { DurableObject } from "cloudflare:workers";
import { handle, newSeed } from "./api.ts";
import { PresenceCounter } from "./presence.ts";
import { D1Store } from "./store.ts";
import { IsolateLimiter } from "./limiter.ts";

// Vive enquanto a instância do Worker viver (spec 010): limite por IP exato
// pra quem martela da mesma região, somado ao rate limiting nativo.
const isolateLimiter = new IsolateLimiter();

export interface Env {
  DB: D1Database;
  PRESENCE: DurableObjectNamespace<Presence>;
  // Segredo pra o hash de IP (limite de partidas) não ser revertível por força
  // bruta; o IP em si nunca é guardado.
  IP_SALT: string;
  // Rate limiting do próprio Workers (spec 010, RF66); ausente em dev local.
  LIMITER?: { limit(options: { key: string }): Promise<{ success: boolean }> };
}

export class Presence extends DurableObject {
  private counter = new PresenceCounter();

  beat(session: string, ipKey: string): { online: number; interval: number } {
    return this.counter.beat(session, Date.now(), ipKey);
  }

  count(): number {
    return this.counter.count(Date.now());
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
      // os dois limites valem: qualquer um que negar barra a requisição
      limit: async (key) => {
        if (!isolateLimiter.allow(key, Date.now())) return false;
        return env.LIMITER ? (await env.LIMITER.limit({ key })).success : true;
      },
      // Sal muda por dia: o mesmo IP não é ligável entre dias.
      ipHash: async (ip) => {
        const day = new Date().toISOString().slice(0, 10);
        const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${env.IP_SALT}:${day}:${ip}`));
        return hex(digest).slice(0, 32);
      },
    });
  },
} satisfies ExportedHandler<Env>;
