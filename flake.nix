{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pre-commit.url = "git+ssh://git@git.wobcom.de/smartmetering/pre-commit-nix.git";
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
          subCmds = [
            "yambs"
          ];
          vendorHash = "sha256-OmxthdcVLsm8tkizrqFegAIgs7oRVFgW25OnbCkwiAU=";
          # render tests call out to W3C validators (no network in sandbox)
          doCheck = false;
        };

        # Generate pre-commit hooks with extras
        preCommitGen = inputs.pre-commit.lib.generate {
          inherit pkgs system;
          src = ./.;
          extra = { };
          extraPackages = [
            pkgs.git
          ];
          extraShellHook = ''
            echo "Extra shellHook on entering DevShell"
          '';
        };

      in
      {
        packages.default = yambs;
        checks.pre-commit-check = preCommitGen.pre-commit-check;
        inherit (preCommitGen) formatter;
        devShells.default = preCommitGen.devShell;
      }
    );
}
