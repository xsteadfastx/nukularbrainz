# Download & pre-tag Radio Nukular episodes for beets import

## Goal

Make importing the Radio Nukular podcast into beets one-shot: download every
episode's audio, pre-tag each file with its MusicBrainz release ID, then
`beet import` matches directly (beets reads the `MusicBrainz Album Id` tag as
a strong match candidate).

Releases for episodes 1–100 already exist in MusicBrainz (created via
`seed-nukular`), so the tag step only *reads* existing releases — no seeding
coordination.

## Approach

Write the MBID into each file with `mutagen` (no beets dependency in the
flake). beets reads the tag on import.

## Components

### `download-episodes` (new flake output)

- curl the feed, pull each `<enclosure url>` + `<title>` per `<item>`
- save into `./episodes/` (overridable via first arg), named
  `NNN - Title.mp3` (zero-padded episode number, same convention as
  `download-covers`)
- skip files that already exist
- mp3 only

### `tag-episodes` (new flake output)

- query `https://musicbrainz.org/ws/2/release?artist=<Radio Nukular MBID>&fmt=json`,
  paginated (100+ releases)
- build `{episode# → release-mbid}` from release titles
  (`Radio Nukular #272, "…"`)
- for each file in `./episodes/`, extract episode# from the filename
- write `MUSICBRAINZ_ALBUMID` (+ artist + release-group ids) via `mutagen`
- print matched / unmatched so gaps are visible

### `.gitignore`

- add `episodes/` (keep the dir, ignore the audio — same pattern as
  `cover-art/`)

### Runtime inputs

- add `pkgs.python3Packages.mutagen` to both scripts

## Usage

```bash
download-episodes && tag-episodes && beet import episodes/
```

## Out of scope

- m4a/flac support (mp3 only)
- creating releases (already done via `seed-nukular`)
- the series relationship (manual, unchanged)
