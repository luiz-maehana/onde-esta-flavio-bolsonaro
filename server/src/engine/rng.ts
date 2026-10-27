// Réplica bit a bit do RandomNumberGenerator do Godot 4 (PCG32, mesmo
// incremento padrão e mesmo sorteio limitado por rejeição) e do hash() de
// String (djb2 sobre code points). O servidor do ranking refaz casos do
// jogo; qualquer diferença aqui muda o resultado — ver test/parity.test.ts.

const MASK64 = (1n << 64n) - 1n;
const MULT = 6364136223846793005n;
const DEFAULT_INC = 1442695040888963407n;

export class GodotRng {
  seed = 0;
  private state = 0n;
  private inc = 0n;

  constructor(seed: number) {
    this.setSeed(seed);
  }

  // pcg32_srandom_r(state, initstate = seed, initseq = DEFAULT_INC)
  setSeed(seed: number): void {
    this.seed = seed;
    const s = BigInt(seed) & MASK64;
    this.state = 0n;
    this.inc = ((DEFAULT_INC << 1n) | 1n) & MASK64;
    this.next();
    this.state = (this.state + s) & MASK64;
    this.next();
  }

  // pcg32_random_r
  next(): number {
    const old = this.state;
    this.state = (old * MULT + this.inc) & MASK64;
    const xorshifted = Number((((old >> 18n) ^ old) >> 27n) & 0xffffffffn);
    const rot = Number(old >> 59n);
    return ((xorshifted >>> rot) | (xorshifted << ((-rot) & 31))) >>> 0;
  }

  randi(): number {
    return this.next();
  }

  // pcg32_boundedrand_r: rejeita abaixo do limiar pra não enviesar.
  private bounded(bound: number): number {
    const threshold = (0x100000000 - bound) % bound;
    for (;;) {
      const r = this.next();
      if (r >= threshold) return r % bound;
    }
  }

  // RandomPCG::random(from, to)
  randiRange(from: number, to: number): number {
    if (from === to) return from;
    return this.bounded(Math.abs(from - to) + 1) + Math.min(from, to);
  }
}

// String::hash() do Godot: djb2 (h * 33 + c) sobre code points, 32 bits.
export function godotHash(s: string): number {
  let h = 5381;
  for (const ch of s) {
    h = (Math.imul(h, 33) + (ch.codePointAt(0) as number)) >>> 0;
  }
  return h;
}
