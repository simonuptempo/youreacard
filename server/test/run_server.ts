import { register } from "node:module";
register("./loader.mjs", import.meta.url);
(globalThis as any).Deno = { env: { get: () => "mock" }, serve: (h: any) => { (globalThis as any).__handler = h; } };
const { serve } = await import("./mock_supabase.ts");
await import("../functions/gem-heist/index.ts");
serve((globalThis as any).__handler, 54321);
console.log("mock supabase on 54321");
