// Partida plausível (spec 010, RF64): só vai pro ranking a partida que uma
// pessoa poderia ter jogado. A semente vai pro cliente e o código é aberto,
// então um programa consegue ler a solução direto do caso gerado; estas
// regras não impedem a partida (ela conta pro jogador), só a publicação.
//
// - rápido demais: menos de MIN_RUN_SECONDS, ou de MIN_SECONDS_PER_ACTION
//   por ação;
// - viajou pro destino certo sem investigar a cidade (a pista do destino
//   vem das testemunhas);
// - emitiu a pauta antes de ouvir MIN_TRAITS_FOR_PAUTA características.

import { generate, type Config } from "./engine/case.ts";
import { GodotRng } from "./engine/rng.ts";

export const MIN_RUN_SECONDS = 60;
export const MIN_SECONDS_PER_ACTION = 3;
export const MIN_TRAITS_FOR_PAUTA = 2;

export type Flag = "too_fast" | "blind_travel" | "blind_pauta";

/** null = plausível; senão, o motivo da marca. */
export function implausible(seed: number, config: Config, actions: string[][], elapsedMs: number): Flag | null {
  const seconds = elapsedMs / 1000;
  if (seconds < MIN_RUN_SECONDS || seconds < actions.length * MIN_SECONDS_PER_ACTION) return "too_fast";

  const s = generate(new GodotRng(seed), config);
  const heard = new Set<string>();
  // vale a última pauta: chutar cedo e reemitir depois de ouvir é humano
  let lastPautaHeard = Infinity;
  for (const a of actions) {
    if (a[0] === "t" && s.isOnTrail() && !s.isFinalStop() && a[1] === s.route[s.stopIndex + 1]) {
      if ((s.visited.get(s.currentCity) ?? []).length === 0) return "blind_travel";
    }
    if (a[0] === "i" && s.isOnTrail() && !s.isFinalStop()) {
      const plan = s.traitPlan.get(s.stopIndex);
      if (plan && s.locationsHere().indexOf(a[1]) === plan.slot) heard.add(plan.trait);
    }
    if (a[0] === "p") lastPautaHeard = heard.size;
    if (!s.replayAction(a)) return null; // ação ilegal: o replay principal já recusa
  }
  return lastPautaHeard < MIN_TRAITS_FOR_PAUTA ? "blind_pauta" : null;
}
