export async function resolve(spec, ctx, next) {
  if (spec.startsWith("npm:@supabase/supabase-js")) return { url: new URL("./sb_shim.ts", import.meta.url).href, shortCircuit: true };
  return next(spec, ctx);
}
