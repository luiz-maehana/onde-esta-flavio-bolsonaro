// Os MESMOS arquivos de dados do jogo (data/*.json) — fonte única; o
// servidor nunca tem uma cópia que possa divergir.
import citiesJson from "../../../data/cities.json" with { type: "json" };
import disguisesJson from "../../../data/disguises.json" with { type: "json" };
import flavorJson from "../../../data/flavor.json" with { type: "json" };
import scandalsJson from "../../../data/scandals.json" with { type: "json" };
import targetsJson from "../../../data/targets.json" with { type: "json" };

export type City = { id: string; name: string; lat: number; lon: number; coastal: boolean; clues: string[] };
export type Disguise = { id: string; name: string; [trait: string]: unknown };
export type Scandal = { id: string; reasons: string[]; found_spots: string[]; [k: string]: unknown };
export type Rank = { title: string; min_cases: number; route_len: number; deadline: number; decoys: string; trait_clues: number; target_chance?: number };
export type Target = { id: string; scandal?: Scandal };

export const cities = citiesJson as unknown as City[];
export const disguiseData = disguisesJson as unknown as {
  trait_order: string[];
  traits: Record<string, Record<string, { label: string; witness: string[] }>>;
  disguises: Disguise[];
};
export const flavor = flavorJson as unknown as Record<string, any> & { ranks: Rank[] };
export const scandals = scandalsJson as unknown as Scandal[];
export const targets = targetsJson as unknown as Target[];
// Parceiros (spec 009): alvos com escândalo próprio — todos menos o Flávio.
export const partners = targets.filter((t) => t.scandal !== undefined);

const cityById = new Map(cities.map((c) => [c.id, c]));

export function city(id: string): City | undefined {
  return cityById.get(id);
}

export function disguise(id: string): Disguise | undefined {
  return disguiseData.disguises.find((d) => d.id === id);
}

export function traitValues(trait: string): string[] {
  return Object.keys(disguiseData.traits[trait] ?? {});
}
