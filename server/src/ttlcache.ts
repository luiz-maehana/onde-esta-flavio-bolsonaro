// Cache com validade (spec 010): o ranking é lido do D1 no máximo uma vez por
// período a cada TTL, não importa quantas consultas cheguem. Vive no Durable
// Object (instância única e global) — no domínio workers.dev o Cache API não
// funciona e a memória de cada instância do Worker vê só uma fração do
// tráfego. Consultas simultâneas com o cache vencido esperam a mesma leitura.

export class TtlCache<T> {
  private readonly entries = new Map<string, { at: number; value: Promise<T> }>();
  private readonly ttlMs: number;

  constructor(ttlMs: number) {
    this.ttlMs = ttlMs;
  }

  get(key: string, now: number, load: () => Promise<T>): Promise<T> {
    const hit = this.entries.get(key);
    if (hit && now - hit.at < this.ttlMs) return hit.value;
    const value = load();
    this.entries.set(key, { at: now, value });
    // leitura que falhou não fica no cache
    value.catch(() => {
      if (this.entries.get(key)?.value === value) this.entries.delete(key);
    });
    return value;
  }
}
