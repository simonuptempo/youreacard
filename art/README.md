# You're a Card — standalone art pack

15 PNG assets, generated with the built-in image_gen tool and exported at the requested dimensions. The shared style is premium tabletop illustration with ivory card stock, antique brass trim, jewel colors, and softly shaded materials. Exact prompts are in `manifest.json`; PNG checks are in `validation.json`.

## Asset map

| Files | Pixels | Transparency |
|---|---|---|
| treasure-ruby.png, treasure-emerald.png, treasure-sapphire.png | 512 × 512 | Transparent background |
| treasure-gold.png, treasure-pearl.png, treasure-crown.png | 512 × 512 | Transparent background |
| card-back.png | 600 × 840 | Opaque |
| frame-treasure.png, frame-heist.png, frame-trap.png, frame-tool.png, frame-wild.png | 600 × 840 | Transparent center and outer corners |
| logo.png | 1600 × 700 | Transparent background |
| table-background.png | 1080 × 1920 | Opaque |
| app-icon.png | 1024 × 1024 | RGB, no alpha channel |

## Godot integration notes for Claude

- Files live directly under `res://art/` after installation. No scripts or scenes were changed by this art delivery.
- Replace the treasure drawing in `CardView._treasure_icon` with the matching texture. Preserve aspect ratio and include the existing image padding when choosing display size. Retain procedural drawing as a missing-asset fallback.
- Draw a native ivory rounded card base first, then the transparent frame, then the native title, avatar/art, and rules. These frames are perimeter overlays, not full card faces or prebuilt title/rules panels. Use native title and type labels; the accents alone should not identify type.
- Frame accents: treasure = gold, heist = burgundy, trap = purple, tool = sapphire blue, wild = emerald green. Central safe region is x=12–88%, y=12–88% of each 600×840 texture (x=72–528, y≈101–739). The center has been checked in that region: alpha is 0 except for sparse residual pixels at 1/255 opacity (under 0.5% of the safe-region pixels in every frame), visually transparent but not a mathematically empty mask. See validation.json for exact values. Adjust layout thoughtfully for the existing title/footer, rather than drawing opaque panels across the decorative perimeter.
- Render cards at 5:7 aspect when practical. Frame variants share a visual template but are raster illustrations, not pixel-identical nine-patch borders. Prefer whole-texture scaling with linear filtering; check actual hand-card sizes. Keep selected/highlight outlines and dimming above all visual layers.
- Card back is a full-bleed opaque rectangle. Clip it to the card's rounded shape. It uses a two-way decorative motif; shading and texture are not guaranteed mathematically rotationally identical.
- Place the background behind UI without stretching card or text elements. Its low-contrast forest felt should remain visually quiet.
- Use the logo with aspect preserved, including its transparent padding. Only the logo contains text. Card titles/rules stay native.
- App icon is the requested opaque square master. Platform export configuration and platform-specific icon packaging remain with the app integration.
- Do not replace customizable avatar layers or costumes with these assets. They remain managed by the existing avatar system.

## Verification scope
All outputs were visually inspected during generation. Dimensions and PNG transparency were checked after export. Actual Godot layout, import settings, and gameplay rendering must be checked when the textures are connected.

Selected branding: Playful Caper (option 2). logo.png is the selected transparent wordmark; app-icon.png is the matching masked heart-card mascot with the title on an opaque gold square. App icon is a 1024×1024 RGB PNG with no alpha and no pre-rounded outer corners. Connect it through the Godot iOS export icon setting / Xcode app-icon asset catalog. No App Store submission has been performed.

Latest icon revision: the upper heart is replaced with the title printed directly on the card; the lower heart is retained. app-icon.png remains 1024×1024 RGB, opaque.
