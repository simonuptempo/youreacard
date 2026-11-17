#!/usr/bin/env python3
"""Add ElevenLabs voice clips to the game.

  python3 tools/add_voices.py <clip files...>

Each file is named <character>_<voice>_<words of the line>.mp3, e.g.
pickpocket_boy_too_slow.mp3 or wildcard_androgynous_surprise.mp3 (wildcard_nanabea_... is
Nana Bea, the Wild's own character, saved as you_nana_<n>). The character and
the words pick the line from audio/voice_lines.json; the voice word decides whether it
is the character's regular voice or the other-gender one (saved as <role>_alt_<n>).
Clips are trimmed, volume-matched and written to audio/voice_real/<role>_<n>.ogg.
"""
import json, os, re, subprocess, sys, difflib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINES = json.load(open(os.path.join(ROOT, "audio", "voice_lines.json")))
ALIASES = {"wildcard": "you", "wild": "you"}
REGULAR = {"you": "", "pickpocket": "boy", "trickster": "woman", "boss": "man", "mastermind": "woman",
           "bouncer": "man", "illusionist": "woman", "trapper": "woman", "locksmith": "woman"}
VOICE_WORDS = {"boy", "girl", "man", "woman", "male", "female", "androgynous", "neutral", "nanabea"}
NORMAL = {"male": "man", "female": "woman", "neutral": "", "androgynous": ""}
FILTER = ("silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.03,areverse,"
          "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08,areverse,"
          "loudnorm=I=-16:TP=-1.5:LRA=11")

squash = lambda t: re.sub(r"[^a-z0-9]", "", t.lower())


def place(path):
    name = os.path.splitext(os.path.basename(path))[0]
    name = re.sub(r"^[0-9a-f]{8}-", "", name)          # upload prefix
    words = name.lower().split("_")
    role = ALIASES.get(words[0], words[0])
    if role not in LINES:
        return None, f"unknown character '{words[0]}'"
    rest = words[1:]
    voice = REGULAR[role]
    if rest and rest[0] in VOICE_WORDS:
        voice = NORMAL.get(rest[0], rest[0])
        rest = rest[1:]
    nana = voice == "nanabea"   # the Wild's own character, Nana Bea: saved as you_nana_<n>
    alt = not nana and voice not in ("", REGULAR[role])
    said = squash("".join(rest))
    scores = [difflib.SequenceMatcher(None, said, squash(l)).ratio() for l in LINES[role]]
    i = max(range(len(scores)), key=scores.__getitem__)
    if scores[i] < 0.75:
        return None, f"no line matches '{' '.join(rest)}' (closest: {LINES[role][i]})"
    stem = f"{role}_nana_{i}" if nana else (f"{role}_alt_{i}" if alt else f"{role}_{i}")
    return stem, LINES[role][i]


def main(paths):
    out_dir = os.path.join(ROOT, "audio", "voice_real")
    os.makedirs(out_dir, exist_ok=True)
    done = {}
    for p in paths:
        stem, info = place(p)
        if stem is None:
            print(f"SKIPPED {os.path.basename(p)}: {info}")
            continue
        if stem in done:
            print(f"SKIPPED {os.path.basename(p)}: same line as {done[stem]}")
            continue
        dst = os.path.join(out_dir, stem + ".ogg")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", p, "-af", FILTER, "-ar", "44100", "-ac", "1",
                        "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
        done[stem] = os.path.basename(p)
        print(f"{stem:16} {info}")


if __name__ == "__main__":
    main(sys.argv[1:])
