# War and Piece voices

80 supplied recordings: 20 each for Amara, Juno, Lou and Pip.

`war_voice_catalog.gd` maps each clip to a gameplay situation. `war_voice.gd` owns the voice channel. The cast cheers for the player; opponent wins do not trigger player-victory lines. Generic closing lines can play after a loss. Dev remains in the shield rotation.

Sometimes: 30% ordinary / 70% major event chance, 12-second minimum spacing.
Often: 60% ordinary / 90% major event chance, 8-second minimum spacing.
Off or sound muted: no audio playback; the same occasional reactions still display as speech bubbles. Changing to muted stops active speech. Nothing queues; events during speech or cooldown are skipped. Avoid the last ten clips when possible and never immediately repeat the same clip. Favor a different speaker when available.

Custom event-specific WAV replacements can live at `user://voices/war_and_piece/<original_mp3_basename>.wav`. The existing Gem Heist recording prompts are deliberately not substituted. A dedicated recording UI for these prompts is not implemented here.

Run `tests/voice_playback.gd`, `tests/animation_flow.gd`, and `tests/shield_ui.gd` for verification.

Face-off and tie reactions are restricted to characters face-up in the actual battle pile. The selected speaking card leads collection and remains the visual top of the winnings pile; no game-state card order is changed. Captions share the selected clip text and remain visible long enough to read.
