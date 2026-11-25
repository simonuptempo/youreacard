// Turns a photo into a cartoon portrait for a card, using Google Gemini 2.5 Flash Image.
// The photo is sent to Gemini and the cartoon comes back to the phone; nothing is stored
// here except a count per device per day (limits keep the cost predictable).
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});
const GEMINI_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const MODEL = Deno.env.get("GEMINI_IMAGE_MODEL") ?? "gemini-2.5-flash-image";
const PER_DEVICE_PER_DAY = Number(Deno.env.get("CARTOONS_PER_DEVICE_PER_DAY") ?? "15");
const ALL_PER_DAY = Number(Deno.env.get("CARTOONS_PER_DAY") ?? "400");

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

// What each card's character wears, so your cartoon fits the card.
const COSTUME: Record<string, string> = {
  you: "a sparkly, colorful outfit with a rainbow gem brooch",
  pickpocket: "a small black domino eye mask and a red-and-white striped scarf",
  trickster: "a top hat, fanning out a hand of playing cards",
  boss: "a pinstriped suit with a bow tie, holding a walking cane",
  mastermind: "an elegant purple outfit, holding a rolled-up blueprint",
  bouncer: "dark sunglasses and a black security T-shirt, arms crossed",
  illusionist: "a purple magician's cape covered in little sparkles",
  trapper: "a safari hat, with a coil of rope over one shoulder",
  locksmith: "a work apron, holding a giant golden key",
};

const STYLE =
  "Style: a warm, friendly cartoon for a family card game, with clean bold outlines, soft cel shading and bright cheerful colors, " +
  "like a modern storybook illustration. Show the head and shoulders, facing the viewer, centered and filling most of the square. " +
  "A plain, flat light cream background: one solid color with no shading, texture, shadow or scenery " +
  "(the app cuts it out). No text, no frame, no border.";

function prompt(kind: string, role: string): string {
  const costume = COSTUME[role] ? ` wearing ${COSTUME[role]}` : "";
  if (kind === "pet") {
    return "Redraw the pet in this photo as a cute cartoon character" + costume + ". " +
      "Keep it clearly the same animal: its breed features, fur colors and markings, ear shape and eye color. " + STYLE;
  }
  return "Redraw the person in this photo as a cartoon character" + costume + ", with a happy expression. " +
    "Keep their likeness: the same face shape, skin tone, eye color, hair style and color, and any glasses or facial hair. " + STYLE;
}

// "Change the look": the same options as the in-game character builder, and nothing else,
// so the request can never carry free text to the image model.
const COLORS = ["Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Navy", "Purple", "Pink", "Brown", "Black", "White", "Gray"];
const PERSON_LOOKS: Record<string, [string, string[]]> = {
  hair: ["Hair style", ["Bald", "Buzz", "Short", "Side part", "Fade", "Wavy", "Long straight", "Curly", "Coily",
    "Afro", "Locs", "Box braids", "Two puffs", "Bun", "Ponytail", "Bob", "Mohawk", "Receding"]],
  hair_color: ["Hair color", ["Black", "Dark brown", "Brown", "Light brown", "Auburn", "Red", "Blonde", "Platinum blonde",
    "Gray", "White", "Blue", "Pink", "Purple", "Green"]],
  facial: ["Facial hair", ["None", "Stubble", "Mustache", "Goatee", "Full beard", "Long beard"]],
  hat: ["Hat", ["None", "Cap", "Beanie", "Sun hat", "Cowboy hat", "Bucket hat", "Crown", "Party hat"]],
  head: ["Head covering", ["None", "Hijab", "Turban", "Patka", "Kippah", "Headwrap", "Durag", "Bonnet"]],
  eyewear: ["Glasses", ["None", "Round glasses", "Square glasses", "Cat-eye glasses", "Sunglasses", "Eye patch"]],
  ears: ["Ears", ["None", "Hearing aid", "Cochlear implant", "Earrings", "Hoops"]],
  shirt: ["Outfit", ["Tee", "Hoodie", "Collar", "Sweater", "Overalls", "Jersey", "Blazer", "Henley", "Cardigan"]],
  shirt_color: ["Outfit color", COLORS],
  bowtie: ["Bow tie", ["None", "Bow tie"]],
  braces: ["Braces", ["None", "Braces"]],
  details: ["Face detail", ["Freckles", "Vitiligo", "Rosy cheeks", "Smile lines", "Birthmark", "Bindi", "Nose ring", "Makeup"]],
};
const PET_LOOKS: Record<string, [string, string[]]> = {
  hat: PERSON_LOOKS.hat,
  eyewear: PERSON_LOOKS.eyewear,
  collar: ["Collar", ["None", "Collar", "Bell collar", "Bandana", "Bow tie"]],
  collar_color: ["Collar color", COLORS],
};

function editPrompt(kind: string, edits: Record<string, unknown>): string | null {
  const looks = kind === "pet" ? PET_LOOKS : PERSON_LOOKS;
  const lines: string[] = [];
  for (const [key, value] of Object.entries(edits ?? {})) {
    const look = looks[key];
    const v = String(value);
    if (!look || !look[1].includes(v)) continue;
    if (key === "details") lines.push(`- Add: ${v.toLowerCase()}`);
    else if (v === "None") lines.push(`- ${look[0]}: none (remove it)`);
    else lines.push(`- ${look[0]}: ${v.toLowerCase()}`);
  }
  if (lines.length === 0) return null;
  return "Edit this cartoon portrait. Make only these changes:\n" + lines.join("\n") + "\n" +
    "Keep everything else exactly the same: the same character and likeness, face, expression, pose, art style, " +
    "colors, background and framing. No text, no frame, no border.";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);
  if (!GEMINI_KEY) return json({ error: "Cartoons aren't set up yet. Please try again later." }, 503);
  try {
    const body = await req.json().catch(() => ({}));
    const image = String(body.image ?? "");
    const mime = body.mime === "image/png" ? "image/png" : "image/jpeg";
    const kind = body.kind === "pet" ? "pet" : "person";
    const role = String(body.role ?? "");
    const editing = body.mode === "edit";
    const text = editing ? editPrompt(kind, body.edits) : prompt(kind, role);
    if (!text) return json({ error: "Pick at least one change." }, 400);
    const device = String(body.device ?? "").replace(/[^A-Za-z0-9_.:-]/g, "").slice(0, 64) ||
      (req.headers.get("x-forwarded-for") ?? "unknown").split(",")[0].trim();
    if (image.length < 100) return json({ error: "No photo was sent." }, 400);
    if (image.length > 4_000_000) return json({ error: "That photo is too large. Please choose a smaller one." }, 413);

    const { data: usage, error: usageErr } = await db.rpc("bump_cartoon_usage", { p_device: device });
    if (usageErr) throw usageErr;
    const u = Array.isArray(usage) ? usage[0] : usage;
    if (u && u.device_count > PER_DEVICE_PER_DAY) return json({ error: "That's all the cartoons for today. Try again tomorrow!" }, 429);
    if (u && u.total > ALL_PER_DAY) return json({ error: "Cartoons are very popular today. Please try again tomorrow." }, 429);

    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
      method: "POST",
      headers: { "x-goog-api-key": GEMINI_KEY, "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text }, { inline_data: { mime_type: mime, data: image } }] }],
        generationConfig: { responseModalities: ["IMAGE"], imageConfig: { aspectRatio: "1:1" } },
      }),
    });
    const out = await res.json().catch(() => ({}));
    if (!res.ok) {
      console.error("gemini", res.status, JSON.stringify(out).slice(0, 500));
      return json({ error: "The cartoon maker is busy. Please try again in a minute." }, 502);
    }
    const parts = out?.candidates?.[0]?.content?.parts ?? [];
    const pic = parts.find((p: any) => p.inlineData?.data || p.inline_data?.data);
    if (!pic) {
      // Usually a safety block (for example, photos of young children) or no clear face.
      console.error("gemini no image", JSON.stringify(out).slice(0, 500));
      return json({ error: "Couldn't make a cartoon from that photo. Try a clear, well-lit photo." }, 422);
    }
    const d = pic.inlineData ?? pic.inline_data;
    return json({ image: d.data, mime: d.mimeType ?? d.mime_type ?? "image/png" });
  } catch (e) {
    console.error(e);
    return json({ error: "Something went wrong making your cartoon. Please try again." }, 500);
  }
});
