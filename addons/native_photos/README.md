# Native photos (iOS)

Opens the iPhone's own camera and Photos picker for the card maker, and hands the
picture to the game as JPEG bytes (`NativePhotos` singleton, signals `photo_ready`,
`photo_cancelled`, `photo_failed`). On a Mac it loads but reports "not available",
so the editor keeps using the game's own screens.

GitHub builds it automatically (`.github/workflows/native-photos.yml`) whenever
`src/` changes, and commits the results to `bin/` plus `native_photos.gdextension`.
