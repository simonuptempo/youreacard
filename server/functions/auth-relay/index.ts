// Apple / Google / Facebook sign-in for the Gem Heist app.
// 1. The app opens the provider in the browser with redirect_to = this function + ?lid=<random>.
// 2. Supabase sends the browser here with ?code=...; we hold the code under that lid and
//    send the player to a friendly "go back to the app" page.
// 3. The app polls ?poll=<lid>, gets the code once, and trades it (with its secret PKCE
//    verifier, which never leaves the phone) for a session.
import { createClient } from "npm:@supabase/supabase-js@2";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});
const SITE = "https://youreacard.lovable.app";
const LID = /^[A-Za-z0-9]{16,64}$/;
const json = (b: unknown) => new Response(JSON.stringify(b), { headers: { "Content-Type": "application/json" } });
const go = (path: string) => new Response(null, { status: 302, headers: { Location: SITE + path } });

Deno.serve(async (req) => {
  const u = new URL(req.url);
  const poll = u.searchParams.get("poll");
  if (poll !== null) {
    if (!LID.test(poll)) return json({});
    const { data } = await db.from("auth_relay").select("code, created_at").eq("lid", poll).maybeSingle();
    if (!data) return json({});
    await db.from("auth_relay").delete().eq("lid", poll);
    if (Date.now() - new Date(data.created_at).getTime() > 10 * 60 * 1000) return json({});
    return json({ code: data.code });
  }
  const lid = u.searchParams.get("lid") ?? "";
  const code = u.searchParams.get("code") ?? "";
  if (LID.test(lid) && code && code.length < 512) {
    await db.from("auth_relay").upsert({ lid, code, created_at: new Date().toISOString() });
    // Tidy up anything older than an hour.
    await db.from("auth_relay").delete().lt("created_at", new Date(Date.now() - 3600 * 1000).toISOString());
    return go("/signed-in");
  }
  return go("/signed-in?error=1");
});
