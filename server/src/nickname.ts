// Apelido público do ranking: só letras (com acento), números, espaço e
// . _ - ; até 18 caracteres. Termos ofensivos viram "Repórter Anônimo".
// Moderação fina (remover uma entrada) é feita no console do D1.

export const MAX_NICKNAME = 18;
export const ANONYMOUS = "Repórter Anônimo";

// Comparação sem acento, minúscula e com troca de "leet" comum (0->o, 1->i...).
function fold(s: string): string {
  return s
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/0/g, "o")
    .replace(/1/g, "i")
    .replace(/3/g, "e")
    .replace(/4/g, "a")
    .replace(/5/g, "s")
    .replace(/7/g, "t")
    .replace(/[^a-z ]/g, "");
}

// Bloqueados em qualquer posição do apelido.
const BLOCK_ANYWHERE = [
  "porra", "caralh", "merda", "puta", "buceta", "boceta", "foder", "fodase", "arrombad", "corno",
  "viado", "bicha", "sapatao", "traveco", "macaco", "crioulo", "nazi", "hitler", "estupr", "pedofil",
  "piroca", "pinto", "cuzao", "xoxota", "bosta", "vagabund", "prostitut",
];
// Curtos demais pra buscar dentro de palavras ("cu" em "curitiba"): só a palavra inteira.
const BLOCK_WORDS = ["cu", "fdp", "pqp", "vsf", "tnc", "krl", "porr", "foda"];

export function isOffensive(nick: string): boolean {
  const f = fold(nick);
  const joined = f.replace(/ /g, "");
  if (BLOCK_ANYWHERE.some((w) => joined.includes(w))) return true;
  return f.split(" ").some((w) => BLOCK_WORDS.includes(w));
}

export function sanitizeNickname(input: unknown): string {
  if (typeof input !== "string") return ANONYMOUS;
  const clean = input
    .normalize("NFC")
    .replace(/[^\p{L}\p{N} ._-]/gu, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, MAX_NICKNAME)
    .trim();
  if (clean.length < 2 || isOffensive(clean)) return ANONYMOUS;
  return clean;
}
