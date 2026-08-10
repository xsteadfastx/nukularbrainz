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
        checks.pre-commit-check = preCommitGen.pre-commit-check;
        inherit (preCommitGen) formatter;
        devShells.default = preCommitGen.devShell;
      }
    );
}
