// Limite de requisições por chave (hash do IP) em memória, dentro da
// instância do Worker (spec 010, RF66). Complementa o rate limiting nativo
// do Workers, que na prática deixou passar ~170 req/min por IP no plano
// grátis. Uma instância atende uma região, então quem martela do mesmo lugar
// cai nela; janela fixa de 1 minuto, memória limitada.

export const LIMIT_PER_MINUTE = 60;
const WINDOW_MS = 60_000;
// Teto de chaves guardadas (um ataque com milhares de IPs não enche a memória).
const MAX_KEYS = 10_000;

export class IsolateLimiter {
  private readonly hits = new Map<string, { start: number; count: number }>();
  private readonly limit: number;

  constructor(limit = LIMIT_PER_MINUTE) {
    this.limit = limit;
  }

  /** true = pode passar. */
  allow(key: string, now: number): boolean {
    let h = this.hits.get(key);
    if (!h || now - h.start >= WINDOW_MS) {
      if (!h && this.hits.size >= MAX_KEYS) this.prune(now);
      h = { start: now, count: 0 };
      this.hits.set(key, h);
    }
    h.count++;
    return h.count <= this.limit;
  }

  private prune(now: number): void {
    for (const [key, h] of this.hits) {
      if (now - h.start >= WINDOW_MS) this.hits.delete(key);
    }
    // ainda cheio (todas as chaves ativas): esquece as mais antigas
    for (const key of this.hits.keys()) {
      if (this.hits.size < MAX_KEYS) break;
      this.hits.delete(key);
    }
  }
}
