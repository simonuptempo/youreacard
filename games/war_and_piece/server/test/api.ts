// Tiny client for the mock server (tests only).
export const BASE = "http://127.0.0.1:54321";
export async function signup(name: string, email?: string) {
  const r = await fetch(BASE + "/auth/v1/signup", { method: "POST", body: JSON.stringify({ email, password: email ? "secret1" : undefined, data: { display_name: name } }) });
  return (await r.json()).access_token as string;
}
export async function call(token: string, action: string, body: Record<string, unknown> = {}) {
  const r = await fetch(BASE + "/functions/v1/war-and-piece", { method: "POST", headers: { Authorization: "Bearer " + token, "Content-Type": "application/json" }, body: JSON.stringify({ ...body, action }) });
  return { status: r.status, data: await r.json() as any };
}
// Everything a seat could lock in its hand: 3+ of a kind (good enough for tests).
export function kinds(hand: { id: number; rank: number }[]): number[][] {
  const by: Record<number, number[]> = {};
  for (const c of hand) (by[c.rank] ??= []).push(c.id);
  return Object.values(by).filter((ids) => ids.length >= 3);
}
