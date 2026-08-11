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
            args=(-type release -action serve -set "artist0_name=$ARTIST" -set "edit_note=$EDIT_NOTE")

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
            pkgs.git
            seedNukular
          ];
          extraShellHook = ''
            echo "Extra shellHook on entering DevShell"
          '';
        };

      in
      {
        packages.default = yambs;
        packages.seed-nukular = seedNukular;
        checks.pre-commit-check = preCommitGen.pre-commit-check;
        inherit (preCommitGen) formatter;
        devShells.default = preCommitGen.devShell;
      }
    );
}
