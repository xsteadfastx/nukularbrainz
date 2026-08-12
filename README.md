<div align="center">

# ☢️ Nukular Brainz

**Seed [MusicBrainz](https://musicbrainz.org) edits from the [Radio Nukular](https://www.radionukular.de) podcast — one release per episode, straight from the feed.**

[![Nix](https://img.shields.io/badge/Nix-flake-5277C3?logo=nixos&logoColor=white&style=for-the-badge)](https://nixos.org)
[![yambs](https://img.shields.io/badge/yambs-v0.1.15-4B8BBE?style=for-the-badge)](https://codeberg.org/derat/yambs)
[![MusicBrainz](https://img.shields.io/badge/MusicBrainz-style%20guide-EB743B?style=for-the-badge)](https://musicbrainz.org/doc/Style/Specific_types_of_releases/Podcast_and_broadcast_programs)
[![License](https://img.shields.io/badge/license-unlicensed-9CA3AF?style=for-the-badge)]()

---

*Ein Aufbruch in die Vergangenheit mit 1.21 Gigawatt!* ⚡

</div>

---

## 🧩 What's in the box

| Output | What it is | Why you care |
| --- | --- | --- |
| 🚀 `packages.default` | [`yambs`](https://codeberg.org/derat/yambs) v0.1.15 | The MusicBrainz edit seeder — CSV/TSV, Bandcamp, Qobuz, Tidal, Metal Archives, MP3s, RSS |
| 🎙️ `packages.seed-nukular` | `seed-nukular` | One-click podcast release seeding, MB-style-guide compliant |
| 📥 `packages.download-episodes` | `download-episodes` | Download every episode's audio into `episodes/`, named by episode |
| 🏷️ `packages.tag-episodes` | `tag-episodes` | Pre-tag each episode with its MusicBrainz release ID for beets |
| 🖼️ `packages.download-covers` | `download-covers` | Download each episode's cover art into `cover-art/`, named by episode |
| 🎨 `packages.add-cover` | `add-cover` | Open the add-cover-art page pre-seeded with the matching local image |
| 🛠️ `devShells.default` | Dev shell | `yambs`, `seed-nukular`, `git`, `python3`, `curl` on PATH |
| ✅ `checks.pre-commit-check` | Pre-commit hooks | typos, nixfmt, shellcheck, shfmt, statix, … |
| 🎨 `formatter` | `nixfmt` | One command to keep the flake pretty |

---

## ⚡ Quick start

```bash
# Enter the dev shell — everything's on PATH
nix develop

# Seed one release per Radio Nukular episode, straight into your browser
seed-nukular
```

Or skip the shell entirely:

```bash
nix run .#seed-nukular
```

---

## 🎙️ `seed-nukular`

Fetches the Radio Nukular RSS feed and seeds a **release** for every episode — fully
following the
[MusicBrainz podcast guidelines](https://musicbrainz.org/doc/Style/Specific_types_of_releases/Podcast_and_broadcast_programs).

### ✨ What each release gets

| Field | Value |
| --- | --- |
| **Title** | `Radio Nukular #272, "Battle der Besten: Fahrzeuge der Popkultur"` |
| | `Radio Nukular 2014-12-12, "TMNP-Nachtrag: …"` *(no episode number)* |
| **Release group type** | 🎬 `Broadcast` |
| **Status** | ✅ `Official` |
| **Format** | 💿 `Digital Media` — one track, titled same as the release |
| **Release date** | 📅 Episode publication date (country `XW`) |
| **Artist** | 🎤 `Radio Nukular` |
| **URLs** | ⬇️ download-for-free (audio) · 📝 show-notes (episode page) |

### 🎛️ Options

```bash
seed-nukular                    # open releases in the browser (default)
seed-nukular -action write      # dump the edit HTML to stdout
seed-nukular -action serve      # serve via a short-lived webserver

# Seed only specific episodes (comma-separated numbers and/or ranges)
EPISODES="44,55,57" nix run .#seed-nukular
EPISODES="66-276"  nix run .#seed-nukular
```

> [!NOTE]
> `-action print` doesn't work for releases — they need a **POST** request,
> not a bare URL.

### 📥 Episodes → beets

```bash
# Download every episode's audio into ./episodes, named by episode
# (e.g. "272 - Battle der Besten_ Fahrzeuge der Popkultur.mp3")
download-episodes

# Pre-tag each file with its MusicBrainz release ID (looked up from the
# existing Radio Nukular releases), so beets matches on import
tag-episodes

# Import straight into your beets library
beet import episodes/
```

The `episodes/` folder is git-ignored (only a `.gitkeep` is committed).

### 🖼️ Cover art

```bash
# Download every episode's cover art into ./cover-art, named by episode
# (e.g. "272 - Battle der Besten: Fahrzeuge der Popkultur.jpeg")
download-covers

# After a release is accepted, open its add-cover-art page pre-seeded with the
# matching local image (requires the "MB: Enhanced Cover Art Uploads" userscript)
add-cover <release-mbid> <episode-number>
```

The `cover-art/` folder is git-ignored (only a `.gitkeep` is committed), so
images never land in the repo.

### 🔗 The series relationship

The guidelines recommend collecting episodes in a **series**. yambs can't add
relationships to releases, so once you've created the *Radio Nukular* series in
MusicBrainz, link each release to it manually via a **part of** relationship.

---

## 🚀 `yambs`

The raw [yambs](https://codeberg.org/derat/yambs) binary ships as
`packages.default` for general MusicBrainz seeding:

```bash
nix run .#default -- --help
```

```bash
# Seed a release from a Bandcamp album
nix run .#default -- https://austinwintory.bandcamp.com/album/journey

# Seed standalone recordings from a TSV
nix run .#default -- -type recording -format tsv -fields name,length < recordings.tsv
```

---

## 🧑‍💻 Development

```bash
nix flake check   # run the pre-commit gauntlet
nix fmt           # format the flake
```

---

<div align="center">

Made with ☢️ and a whole lot of nostalgia.

*Radio Nukular is a podcast by Max, Chris & Dominik — this flake is an unofficial fan tool.*

</div>
