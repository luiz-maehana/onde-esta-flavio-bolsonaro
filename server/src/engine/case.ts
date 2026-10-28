// Porte do núcleo do jogo (scripts/core: GameClock, CaseGenerator,
// CaseState e o consumo de rng do ClueBuilder) pra o servidor refazer um
// caso a partir de semente + ações e calcular o desfecho ele mesmo.
// Espelha o GDScript linha a linha — a ORDEM de cada sorteio importa.
// Textos não são montados (o servidor só precisa do desfecho), mas cada
// sorteio que o texto consome no jogo é feito aqui também.

import { GodotRng, godotHash } from "./rng.ts";
import { cities, city, disguise, disguiseData, flavor, scandals, traitValues, type City, type Disguise, type Scandal } from "./data.ts";

export const Outcome = { NONE: 0, WIN: 1, NO_PAUTA: 2, WRONG_PAUTA: 3, TIMEOUT: 4 } as const;

const START_HOUR = 9;
const DEADLINE = 6 * 24 + 17;
const SLEEP_HOUR = 23;
const WAKE_HOUR = 7;
const INVESTIGATE_COSTS = [2, 3, 4];
const REVISIT_COST = 1;
const GAG_PERCENT = 15;
const MIN_TRAVEL_HOURS = 2;
const MAX_TRAVEL_HOURS = 7;
const KM_PER_HOUR = 1600;
const LOCATIONS_PER_CITY = 3;
const DECOYS_PER_STOP = 3;
const NEAR_POOL = 6;
const EARTH_RADIUS_KM = 6371;
export const MAX_ACTIONS = 1000;

export type Config = { route_len: number; deadline: number; decoys: string; trait_clues: number };
export type Action = string[];

export class GameClock {
  hours = START_HOUR;
  deadline = DEADLINE;

  advance(amount: number): boolean {
    this.hours += amount;
    const hod = this.hours % 24;
    if (hod >= SLEEP_HOUR) {
      this.hours = (Math.floor(this.hours / 24) + 1) * 24 + WAKE_HOUR;
      return true;
    }
    if (hod < WAKE_HOUR) {
      this.hours = Math.floor(this.hours / 24) * 24 + WAKE_HOUR;
      return true;
    }
    return false;
  }

  isExpired(): boolean {
    return this.hours > this.deadline;
  }

  hoursLeft(): number {
    return Math.max(0, this.deadline - this.hours);
  }
}

// --- Gerador ---------------------------------------------------------------

export function shuffle<T>(rng: GodotRng, arr: T[]): void {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = rng.randiRange(0, i);
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
}

function pick<T>(rng: GodotRng, arr: T[]): T {
  return arr[rng.randiRange(0, arr.length - 1)];
}

export function distanceKm(a: City, b: City): number {
  const rad = Math.PI / 180;
  const lat1 = a.lat * rad;
  const lat2 = b.lat * rad;
  const dlat = lat2 - lat1;
  const dlon = (b.lon - a.lon) * rad;
  const h = Math.sin(dlat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dlon / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(h));
}

export function pickLocations(rng: GodotRng, c: City): string[] {
  const pool = Object.keys(flavor.locations);
  if (!c.coastal) pool.splice(pool.indexOf("porto"), 1);
  shuffle(rng, pool);
  return pool.slice(0, LOCATIONS_PER_CITY);
}

export function pickDecoys(rng: GodotRng, exclude: string[], count: number): string[] {
  const pool = cities.filter((c) => !exclude.includes(c.id)).map((c) => c.id);
  shuffle(rng, pool);
  return pool.slice(0, count);
}

function pickNearDecoys(rng: GodotRng, exclude: string[], targetId: string, count: number): string[] {
  const target = city(targetId) as City;
  const pool = cities.filter((c) => !exclude.includes(c.id));
  pool.sort((a, b) => distanceKm(a, target) - distanceKm(b, target));
  const near = pool.slice(0, NEAR_POOL).map((c) => c.id);
  shuffle(rng, near);
  return near.slice(0, count);
}

export function configForRank(rankIndex: number): Config {
  const r = flavor.ranks[rankIndex];
  return { route_len: r.route_len, deadline: r.deadline, decoys: r.decoys, trait_clues: r.trait_clues };
}

export function generate(rng: GodotRng, config: Config): CaseState {
  const routeLen = Math.min(10, Math.max(2, Math.trunc(config.route_len)));
  const s = new CaseState();
  s.rng = rng;
  s.caseSeed = rng.seed;
  s.config = config;
  s.clock.deadline = Math.trunc(config.deadline);

  const ids = cities.map((c) => c.id);
  shuffle(rng, ids);
  s.route = ids.slice(0, routeLen);
  s.currentCity = s.route[0];

  for (let i = 0; i < routeLen; i++) {
    const next = i + 1 < routeLen ? s.route[i + 1] : "";
    if (config.decoys === "near" && next !== "") s.decoys.push(pickNearDecoys(rng, s.route, next, DECOYS_PER_STOP));
    else s.decoys.push(pickDecoys(rng, s.route, DECOYS_PER_STOP));
    s.cityLocations.set(s.route[i], pickLocations(rng, city(s.route[i]) as City));
  }
  for (let i = 0; i < routeLen - 1; i++) {
    const clues = [...(city(s.route[i + 1]) as City).clues];
    shuffle(rng, clues);
    s.routeClueCount.push(Math.min(3, clues.length));
  }

  const ds = disguiseData.disguises;
  s.disguise = ds[rng.randiRange(0, ds.length - 1)];
  // _plan_traits
  const traits = [...disguiseData.trait_order];
  shuffle(rng, traits);
  const stops = routeLen - 1;
  const stopOrder = Array.from({ length: stops }, (_, i) => i);
  shuffle(rng, stopOrder);
  const n = Math.min(Math.min(traits.length, stops), Math.max(2, Math.trunc(config.trait_clues)));
  for (let i = 0; i < n; i++) {
    s.traitPlan.set(stopOrder[i], { trait: traits[i], slot: rng.randiRange(0, LOCATIONS_PER_CITY - 1) });
  }
  // state.taunt_plan[chave] = valor — o GDScript avalia o VALOR antes da
  // chave (confirmado pelos vetores de paridade).
  const tauntSlot = rng.randiRange(0, LOCATIONS_PER_CITY - 1);
  const tauntStop = rng.randiRange(0, routeLen - 2);
  s.tauntPlan.set(tauntStop, tauntSlot);

  s.scandal = scandals[rng.randiRange(0, scandals.length - 1)];
  pick(rng, s.scandal.reasons);
  pick(rng, s.scandal.found_spots);
  s.hideoutSlot = rng.randiRange(0, LOCATIONS_PER_CITY - 1);
  return s;
}

// --- Estado e ações ----------------------------------------------------------

type Speech = { kind: "clue" | "cold" | "near" | "found" };

export class CaseState {
  rng = new GodotRng(0);
  clock = new GameClock();
  caseSeed = 0;
  config: Config = { route_len: 5, deadline: DEADLINE, decoys: "random", trait_clues: 4 };
  route: string[] = [];
  decoys: string[][] = [];
  routeClueCount: number[] = [];
  traitPlan = new Map<number, { trait: string; slot: number }>();
  tauntPlan = new Map<number, number>();
  cityLocations = new Map<string, string[]>();
  disguise: Disguise = { id: "", name: "" };
  scandal: Scandal = { id: "", reasons: [], found_spots: [] };
  hideoutSlot = 0;

  stopIndex = 0;
  currentCity = "";
  pauta = "";
  dossier = new Map<string, string>();
  outcome: number = Outcome.NONE;
  visited = new Map<string, string[]>();
  notes = 0;
  actions: Action[] = [];
  wrongCities = 0;
  nights = 0;
  private witnessCache = new Map<string, Speech>();
  private travelCache = new Map<string, string[]>();

  isOnTrail(): boolean {
    return this.currentCity === this.route[this.stopIndex];
  }

  isFinalStop(): boolean {
    return this.stopIndex === this.route.length - 1;
  }

  isOver(): boolean {
    return this.outcome !== Outcome.NONE;
  }

  hoursUsed(): number {
    return this.clock.hours - START_HOUR;
  }

  private subRng(topic: string): GodotRng {
    return new GodotRng(godotHash(`${this.caseSeed}:${topic}`));
  }

  locationsHere(): string[] {
    let locs = this.cityLocations.get(this.currentCity);
    if (!locs) {
      locs = pickLocations(this.subRng("loc:" + this.currentCity), city(this.currentCity) as City);
      this.cityLocations.set(this.currentCity, locs);
    }
    return locs;
  }

  private wasVisited(loc: string): boolean {
    return (this.visited.get(this.currentCity) ?? []).includes(loc);
  }

  private investigateCost(loc: string): number {
    if (this.wasVisited(loc)) return REVISIT_COST;
    const count = (this.visited.get(this.currentCity) ?? []).length;
    return INVESTIGATE_COSTS[Math.min(count, INVESTIGATE_COSTS.length - 1)];
  }

  // ClueBuilder.build: só o tipo da fala + os mesmos sorteios do texto.
  private buildSpeech(slot: number): Speech {
    if (!this.isOnTrail()) {
      pick(this.rng, flavor.cold_trail);
      return { kind: "cold" };
    }
    if (this.isFinalStop()) {
      if (slot === this.hideoutSlot) return { kind: "found" };
      pick(this.rng, this.flavorPool("near"));
      return { kind: "near" };
    }
    const plan = this.traitPlan.get(this.stopIndex);
    if (plan && plan.slot === slot) {
      const value = this.disguise[plan.trait] as string;
      pick(this.rng, disguiseData.traits[plan.trait][value].witness);
    }
    if ((this.tauntPlan.get(this.stopIndex) ?? -1) === slot) {
      pick(this.rng, this.flavorPool("taunts"));
    }
    return { kind: "clue" };
  }

  private flavorPool(key: string): unknown[] {
    return [...(flavor[key] ?? []), ...((this.scandal[key] as unknown[]) ?? [])];
  }

  investigate(loc: string): boolean {
    if (this.isOver() || !this.locationsHere().includes(loc)) return false;
    this.actions.push(["i", loc]);
    let hours = this.investigateCost(loc);
    const first = !this.wasVisited(loc);
    if (first) {
      if (!this.visited.has(this.currentCity)) this.visited.set(this.currentCity, []);
      (this.visited.get(this.currentCity) as string[]).push(loc);
    }
    const slot = this.locationsHere().indexOf(loc);
    const key = `${this.currentCity}:${loc}`;
    if (!this.witnessCache.has(key)) this.witnessCache.set(key, this.buildSpeech(slot));
    const speech = this.witnessCache.get(key) as Speech;

    if (first && this.isOnTrail() && !this.isFinalStop() && this.rng.randiRange(0, 99) < GAG_PERCENT) {
      const gags = this.flavorPool("gags") as { hours: number }[];
      hours += Math.trunc(gags[this.rng.randiRange(0, gags.length - 1)].hours);
    }
    if (this.clock.advance(hours)) this.nights++;
    if (first && speech.kind !== "found") this.notes++;

    if (this.clock.isExpired()) this.outcome = Outcome.TIMEOUT;
    else if (speech.kind === "found") this.outcome = this.captureOutcome();
    return true;
  }

  private captureOutcome(): number {
    if (this.pauta === "") return Outcome.NO_PAUTA;
    if (this.pauta !== this.disguise.id) return Outcome.WRONG_PAUTA;
    return Outcome.WIN;
  }

  travelOptions(): string[] {
    const key = `${this.currentCity}@${this.stopIndex}`;
    const cached = this.travelCache.get(key);
    if (cached) return cached;
    const r = this.subRng("travel:" + key);
    let options: string[];
    if (this.isOnTrail()) {
      options = [...this.decoys[this.stopIndex]];
      if (!this.isFinalStop()) options.push(this.route[this.stopIndex + 1]);
    } else {
      options = [this.route[this.stopIndex], ...pickDecoys(r, [...this.route, this.currentCity], 2)];
    }
    shuffle(r, options);
    this.travelCache.set(key, options);
    return options;
  }

  private travelHours(to: string): number {
    const km = distanceKm(city(this.currentCity) as City, city(to) as City);
    return Math.min(MAX_TRAVEL_HOURS, Math.max(MIN_TRAVEL_HOURS, Math.ceil(km / KM_PER_HOUR) + 1));
  }

  travel(to: string): boolean {
    if (this.isOver() || !this.travelOptions().includes(to)) return false;
    this.actions.push(["t", to]);
    const hours = this.travelHours(to);
    if (this.isOnTrail() && !this.isFinalStop() && to === this.route[this.stopIndex + 1]) this.stopIndex++;
    this.currentCity = to;
    if (!this.isOnTrail()) this.wrongCities++;
    if (this.clock.advance(hours)) this.nights++;
    if (this.clock.isExpired()) this.outcome = Outcome.TIMEOUT;
    return true;
  }

  setPauta(id: string): boolean {
    if (this.isOver() || !disguise(id)) return false;
    this.pauta = id;
    this.actions.push(["p", id]);
    return true;
  }

  setDossier(trait: string, value: string): boolean {
    if (this.isOver() || !disguiseData.trait_order.includes(trait)) return false;
    if (value !== "" && !traitValues(trait).includes(value)) return false;
    this.dossier.set(trait, value);
    this.actions.push(["d", trait, value]);
    return true;
  }

  replayAction(a: unknown): boolean {
    if (!Array.isArray(a) || a.length === 0 || !a.every((p) => typeof p === "string")) return false;
    switch (a[0]) {
      case "i":
        return a.length === 2 && this.investigate(a[1]);
      case "t":
        return a.length === 2 && this.travel(a[1]);
      case "p":
        return a.length === 2 && this.setPauta(a[1]);
      case "d":
        return a.length === 3 && this.setDossier(a[1], a[2]);
    }
    return false;
  }
}

// Refaz um caso inteiro; null se alguma ação for inválida.
export function replay(seed: number, config: Config, actions: unknown): CaseState | null {
  if (!Array.isArray(actions) || actions.length > MAX_ACTIONS) return null;
  const s = generate(new GodotRng(seed), config);
  for (const a of actions) {
    if (!s.replayAction(a)) return null;
  }
  return s;
}

// Pontuação (só caso vencido): cargo e tamanho da rota valem, sobra de
// prazo vale, cidade errada desconta.
export function score(s: CaseState, rankIndex: number): number {
  if (s.outcome !== Outcome.WIN) return 0;
  const base = (rankIndex + 1) * 100 + s.route.length * 50;
  return Math.max(10, base + s.clock.hoursLeft() * 2 - s.wrongCities * 40);
}
