// Paridade com o Godot: os vetores (test/vectors.json) são gerados pelo
// próprio jogo (tools/export_parity.gd). Se isto falhar, o servidor
// calcularia resultado diferente do que o jogador viu.
import { test } from "node:test";
import assert from "node:assert/strict";
import vectors from "./vectors.json" with { type: "json" };
import { GodotRng, godotHash } from "../src/engine/rng.ts";
import { replay, type Config } from "../src/engine/case.ts";

test("RandomNumberGenerator: randi e randi_range iguais ao Godot", () => {
  for (const v of vectors.rng) {
    const r = new GodotRng(v.seed);
    assert.deepEqual(v.randi.map(() => r.randi()), v.randi, `randi seed ${v.seed}`);
    for (const [from, to, expected] of v.ranges) {
      assert.equal(r.randiRange(from, to), expected, `randi_range(${from}, ${to}) seed ${v.seed}`);
    }
  }
});

test("hash() de String igual ao Godot", () => {
  for (const v of vectors.hash) assert.equal(godotHash(v.s), v.h, JSON.stringify(v.s));
});

test(`${vectors.cases.length} casos refeitos chegam ao mesmo estado do Godot`, () => {
  for (const [i, c] of vectors.cases.entries()) {
    const s = replay(c.seed, c.config as Config, c.actions);
    assert.ok(s, `caso ${i}: replay recusado`);
    const f = c.final;
    const got = {
      route: s.route, disguise: s.disguise.id, scandal: s.scandal.id, hideout_slot: s.hideoutSlot,
      current_city: s.currentCity, target: s.target, stop_index: s.stopIndex, hours: s.clock.hours, outcome: s.outcome,
      wrong_cities: s.wrongCities, nights: s.nights, pauta: s.pauta, notes: s.notes,
      locations: s.locationsHere(), options: s.isOver() ? [] : s.travelOptions(),
    };
    assert.deepEqual(got, f, `caso ${i} (seed ${c.seed})`);
  }
});

test(`${vectors.rejects.length} saves recusados pelo Godot também são recusados aqui`, () => {
  for (const [i, c] of vectors.rejects.entries()) {
    assert.equal(replay(c.seed, c.config as Config, c.actions), null, `recusa ${i} (tipo ${c.kind}, seed ${c.seed}) foi aceita`);
  }
});
