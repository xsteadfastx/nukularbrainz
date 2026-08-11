{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pre-commit.url = "git+https://git.xsfx.dev/xsteadfastx/pre-commit-nix.git";
  };

  outputs =
    inputs:
    let
      inherit (inputs.flake-utils.lib) eachDefaultSystem;
    in
    eachDefaultSystem (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};

        yambs = pkgs.buildGoModule {
          pname = "yambs";
          version = "0.1.15";
          src = pkgs.fetchgit {
            url = "https://codeberg.org/derat/yambs.git";
            rev = "v0.1.15";
            sha256 = "sha256-gzyRLOi0IWIgr+ITx3njfkMFiQ0D6XyHkM0EqStlQqs=";
          };
          # Use build tags to avoid GCP dependency
          # buildTags = [ "nogcp" ];
          subCmds = [
            "yambs"
          ];
          vendorHash = "sha256-OmxthdcVLsm8tkizrqFegAIgs7oRVFgW25OnbCkwiAU=";
          # render tests call out to W3C validators (no network in sandbox)
          doCheck = false;
        };

        # Seed one MusicBrainz standalone recording per Radio Nukular episode,
        # following the podcast guidelines at
        # https://musicbrainz.org/doc/Style/Specific_types_of_releases/Podcast_and_broadcast_programs
        # (title = episode title, artist = hosts, part-of series relationship).
        # Skips feed items with no duration (yambs rejects zero-length recordings).
        seedNukular = pkgs.writeShellApplication {
          name = "seed-nukular";
          runtimeInputs = [
            yambs
            pkgs.python3
            pkgs.curl
          ];
          text = ''
            set -euo pipefail
            FEED="https://feeds.einfach-podcasten.de/radionukular-mp3"
            ARTIST="Radio Nukular"
            ARTIST_MBID="62cb9850-e9ed-452f-8c3f-7742f0855373"
            EDIT_NOTE="from $FEED"
            tmp="$(mktemp --suffix=.xml)"
            trap 'rm -f "$tmp"' EXIT

            # Seed one release per episode, following the podcast guidelines at
            # https://musicbrainz.org/doc/Style/Specific_types_of_releases/Podcast_and_broadcast_programs
            # yambs sets the Broadcast release-group type, Official status, Digital Media
            # format, release date, and download-for-free + show-notes URLs. The series
            # relationship must be added manually in MusicBrainz (yambs can't add
            # relationships to releases).
            #
            # Default to -action serve (opens a URL in the browser). The default
            # -action open writes a temp .html file and xdg-opens it, which on some
            # systems opens the wrong app (e.g. Calibre). Pass -action write to override.
            # artist0_name prefills the artist search box; artist0_mbid pins the
            # credit directly so it isn't silently dropped on submit.
            args=(-type release -action serve -set "artist0_name=$ARTIST" -set "artist0_mbid=$ARTIST_MBID" -set "edit_note=$EDIT_NOTE")

            curl -s "$FEED" |
              python3 -c '
            import re, sys

            def roman_to_int(s):
                vals = {"I":1,"V":5,"X":10,"L":50,"C":100,"D":500,"M":1000}
                total, prev = 0, 0
                for c in reversed(s.upper()):
                    v = vals[c]
                    total += -v if v < prev else v
                    prev = v
                return total

            def parse_episode(title):
                m = re.match(r"^Episode\s+(\d+)\s*[:\-–]\s*(.+)$", title, re.I)
                if m: return int(m.group(1)), m.group(2).strip()
                m = re.match(r"^Episode\s+([IVXLCDM]+)\s*[:\-–]\s*(.+)$", title, re.I)
                if m: return roman_to_int(m.group(1)), m.group(2).strip()
                m = re.match(r"^#(\d+)\s*[:\-–]?\s*(.+)$", title)
                if m: return int(m.group(1)), m.group(2).strip()
                m = re.match(r"^(\d+)\s*[:\-–]\s*(.+)$", title)
                if m: return int(m.group(1)), m.group(2).strip()
                return None, title

            # Rewrite "Episode NNN - Title" to "#NNN: Title" so yambs release-title
            # logic produces the MB podcast form "Radio Nukular #NNN, \"Title\"".
            def transform(title):
                ep, prog = parse_episode(title)
                if ep:
                    return f"#{ep}: {prog}"
                return title

            data = sys.stdin.read()
            items = re.findall(r"<item>.*?</item>", data, re.S)
            out = []
            for it in items:
                if re.search(r"<itunes:duration>([^<]+)</itunes:duration>", it).group(1) == "00:00:00":
                    continue
                t = re.search(r"<title>(.*?)</title>", it, re.S).group(1)
                t = re.sub(r"^<!\[CDATA\[(.*)\]\]>$", r"\1", t, flags=re.S)
                new = transform(t)
                it = re.sub(r"<title>.*?</title>", lambda m: f"<title>{new}</title>", it, count=1, flags=re.S)
                it = re.sub(r"<itunes:title>.*?</itunes:title>", lambda m: f"<itunes:title>{new}</itunes:title>", it, count=1, flags=re.S)
                out.append(it)
            head = data.split("<item>")[0]
            tail = data.rsplit("</item>", 1)[1]
            sys.stdout.write(head + "".join(out) + tail)
            ' >"$tmp"

            yambs "''${args[@]}" "$@" "$tmp"
          '';
        };

        # Download each episode's cover art from the feed into ./cover-art, named
        # by episode (e.g. "272 - Battle der Besten_ Fahrzeuge der Popkultur.jpg").
        # The folder is git-ignored; the script creates it if missing.
        downloadCovers = pkgs.writeShellApplication {
          name = "download-covers";
          runtimeInputs = [
            pkgs.python3
            pkgs.curl
          ];
          text = ''
            set -euo pipefail
            FEED="https://feeds.einfach-podcasten.de/radionukular-mp3"
            OUT="''${1:-cover-art}"
            mkdir -p "$OUT"

            curl -s "$FEED" | python3 -c '
            import os, re, sys, urllib.request

            def roman_to_int(s):
                vals = {"I":1,"V":5,"X":10,"L":50,"C":100,"D":500,"M":1000}
                total, prev = 0, 0
                for c in reversed(s.upper()):
                    v = vals[c]
                    total += -v if v < prev else v
                    prev = v
                return total

            def parse_episode(title):
                m = re.match(r"^Episode\s+(\d+)\s*[:\-–]\s*(.+)$", title, re.I)
                if m: return int(m.group(1)), m.group(2).strip()
                m = re.match(r"^Episode\s+([IVXLCDM]+)\s*[:\-–]\s*(.+)$", title, re.I)
                if m: return roman_to_int(m.group(1)), m.group(2).strip()
                m = re.match(r"^#(\d+)\s*[:\-–]?\s*(.+)$", title)
                if m: return int(m.group(1)), m.group(2).strip()
                m = re.match(r"^(\d+)\s*[:\-–]\s*(.+)$", title)
                if m: return int(m.group(1)), m.group(2).strip()
                return None, title

            out = sys.argv[1]
            data = sys.stdin.read()
            for it in re.findall(r"<item>.*?</item>", data, re.S):
                img = re.search(r"<itunes:image[^>]*href=\"([^\"]+)\"", it)
                if not img:
                    continue
                url = img.group(1)
                t = re.search(r"<title>(.*?)</title>", it, re.S).group(1)
                t = re.sub(r"^<!\[CDATA\[(.*)\]\]>$", r"\1", t, flags=re.S)
                num, prog = parse_episode(t)
                # Zero-pad the episode number (1 -> 001) so files sort correctly.
                name = f"{num:03d} - {prog}" if num else t
                # Keep title punctuation (e.g. ":") so filenames match the
                # episode/release titles; only strip path separators.
                name = re.sub(r"[/\\]", "_", name)
                name = re.sub(r"\s+", " ", name).strip()
                ext = os.path.splitext(url.split("?")[0])[1] or ".jpg"
                path = os.path.join(out, name + ext)
                if os.path.exists(path):
                    continue
                urllib.request.urlretrieve(url, path)
                print(path)
            ' "$OUT"
          '';
        };

        # Open the MusicBrainz add-cover-art page for a release, pre-seeded with
        # the matching local cover art. Requires the "MB: Enhanced Cover Art
        # Uploads" userscript (seeds the upload form from a URL).
        # Usage: add-cover <release-mbid> <episode-number>
        addCover = pkgs.writeShellApplication {
          name = "add-cover";
          runtimeInputs = [
            pkgs.python3
            pkgs.xdg-utils
          ];
          text = ''
            set -euo pipefail
            MBID="''${1:?usage: add-cover <release-mbid-or-url> <episode-number>}"
            NUM="''${2:?usage: add-cover <release-mbid-or-url> <episode-number>}"
            # Accept a bare MBID or a full release URL; pull the UUID out of either.
            MBID="$(printf '%s' "$MBID" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1 || true)"
            if [ -z "$MBID" ]; then
              echo "could not find a release MBID in '$1'" >&2
              exit 1
            fi
            NUM="$(printf '%03d' "$NUM")"
            file="$(find cover-art -maxdepth 1 -name "$NUM*" -print -quit 2>/dev/null || true)"
            if [ -z "$file" ]; then
              echo "no cover art for episode $NUM in cover-art/" >&2
              exit 1
            fi
            port=8765
            log="$(mktemp)"
            python3 -m http.server "$port" --bind 127.0.0.1 --directory cover-art >"$log" 2>&1 &
            server=$!
            # Keep the server alive in the background so the userscript can fetch
            # the image (HEAD + GET + maxurl re-fetch) at its own pace. xdg-open
            # returns immediately, so without this the server dies before the fetch.
            disown "$server" 2>/dev/null || true
            trap 'kill "$server" 2>/dev/null; rm -f "$log"' EXIT
            sleep 1
            enc="$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$(basename "$file")")"
            url="https://musicbrainz.org/release/$MBID/add-cover-art?x_seed.image.0.url=http://127.0.0.1:$port/$enc&x_seed.image.0.types=[1]&x_seed.origin=Radio%20Nukular"
            xdg-open "$url"
            # Wait until the userscript fetches the image, then keep the server up
            # a little longer for any re-fetch, then stop it.
            for _ in $(seq 1 60); do
              if grep -Fq "$enc" "$log" 2>/dev/null; then
                sleep 30
                break
              fi
              sleep 1
            done
            kill "$server" 2>/dev/null || true
          '';
        };

        # Custom additional hooks
        # extraHooks = {
        #   have-a-nice-day-hook = {
        #     enable = true;
        #     entry = "echo 'have a nice day'";
        #     stages = [ "pre-commit" ];
        #     pass_filenames = false;
        #   };
        # };

        # Generate pre-commit hooks with extras
        preCommitGen = inputs.pre-commit.lib.generate {
          inherit pkgs system;
          src = ./.;
          extra = {
            hooks.typos.settings.configPath = ".typos.toml";
            # hooks = extraHooks;
          };
          extraPackages = [
            addCover
            downloadCovers
            pkgs.git
            seedNukular
          ];
          extraShellHook = ''
            echo "Extra shellHook on entering DevShell"
          '';
        };

      in
      {
        packages = {
          inherit yambs;
          seed-nukular = seedNukular;
          download-covers = downloadCovers;
          add-cover = addCover;
        };
        checks.pre-commit-check = preCommitGen.pre-commit-check;
        inherit (preCommitGen) formatter;
        devShells.default = preCommitGen.devShell;
      }
    );
}
