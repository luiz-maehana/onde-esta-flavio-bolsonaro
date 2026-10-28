// Contador de pessoas online (RF40): sessões que deram sinal (heartbeat)
// recentemente. Lógica pura aqui; o Durable Object (worker.ts) só guarda uma
// instância em memória — se ele reiniciar, o número se refaz sozinho.
//
// Freio de orçamento: o plano gratuito do Cloudflare aceita 100 mil
// requisições/dia (passou disso, a API para até 0h UTC — não há cobrança).
// O servidor devolve de quanto em quanto tempo cada jogador deve mandar o
// próximo sinal, calculado pra os sinais do dia caberem em BEAT_BUDGET (o
// resto fica pra partidas e ranking). Mais gente online = sinal mais
// espaçado; o contador continua funcionando, só atualiza mais devagar.

export const BEAT_BUDGET = 70_000;
export const MIN_INTERVAL_S = 60;
// Uma sessão conta como online por 2,5 intervalos sem sinal.
const WINDOW_FACTOR = 2.5;
// Teto de sessões guardadas: impede encher a memória com ids inventados.
export const MAX_SESSIONS = 50_000;
// Spec 010 (RF66): sessões que um mesmo IP (hash) soma ao contador — uma casa
// com alguns aparelhos, não um script inventando milhares de ids.
export const MAX_SESSIONS_PER_IP = 5;
const DAY_MS = 86_400_000;

export type Beat = { online: number; interval: number };

export class PresenceCounter {
  private readonly seen = new Map<string, number>();
  private readonly ipOf = new Map<string, string>();
  private readonly perIp = new Map<string, number>();
  private day = -1;
  private beatsToday = 0;
  private lastInterval = MIN_INTERVAL_S;

  beat(session: string, now: number, ipKey = ""): Beat {
    const today = Math.floor(now / DAY_MS);
    if (today !== this.day) {
      this.day = today;
      this.beatsToday = 0;
    }
    this.beatsToday++;
    this.prune(now);
    const known = this.seen.has(session);
    const ipFull = ipKey !== "" && (this.perIp.get(ipKey) ?? 0) >= MAX_SESSIONS_PER_IP;
    if (known || (this.seen.size < MAX_SESSIONS && !ipFull)) {
      // re-inserir mantém o Map em ordem de último sinal (prune barato)
      this.seen.delete(session);
      this.seen.set(session, now);
      if (!known && ipKey !== "") {
        this.ipOf.set(session, ipKey);
        this.perIp.set(ipKey, (this.perIp.get(ipKey) ?? 0) + 1);
      }
    }
    const online = this.seen.size;
    this.lastInterval = this.interval(online, now);
    return { online, interval: this.lastInterval };
  }

  count(now: number): number {
    this.prune(now);
    return this.seen.size;
  }

  // Intervalo pra `online` sessões caberem no que sobra do orçamento do dia.
  // Garantia: com clientes obedecendo, o total do dia fica em ~BEAT_BUDGET
  // mais 1 sinal por pessoa — orçamento esgotado = próximo sinal só depois
  // da meia-noite UTC (o contador congela; o resto da API segue).
  interval(online: number, now: number): number {
    const secondsLeft = Math.ceil((DAY_MS - (now % DAY_MS)) / 1000);
    const budgetLeft = BEAT_BUDGET - this.beatsToday;
    if (budgetLeft <= 0) return secondsLeft + MIN_INTERVAL_S;
    const needed = Math.ceil((online * secondsLeft) / budgetLeft);
    return Math.max(MIN_INTERVAL_S, needed);
  }

  private prune(now: number): void {
    const window = this.lastInterval * WINDOW_FACTOR * 1000;
    for (const [session, t] of this.seen) {
      if (now - t <= window) break;
      this.seen.delete(session);
      const ip = this.ipOf.get(session);
      if (ip !== undefined) {
        this.ipOf.delete(session);
        const left = (this.perIp.get(ip) ?? 1) - 1;
        if (left > 0) this.perIp.set(ip, left);
        else this.perIp.delete(ip);
      }
    }
  }
}
