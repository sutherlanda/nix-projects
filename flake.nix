{
  description = "Project template and utilities in Nix.";
  inputs = {
    nixpkgs = {url = github:nixos/nixpkgs;};
    flake-utils = {url = github:numtide/flake-utils;};
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      rootPath = "$PWD";
      projectLib = import ./.;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.allowBroken = true;
      };

      haskellProjectConfigs = [
        rec {
          name = "aoc";
          projectRoot = "${rootPath}/${name}";
          srcDir = "${projectRoot}/src";
          executables = {
            main = "Main.hs";
          };
        }
      ];

      haskellLib = projectLib.lib.projects.haskell {inherit pkgs;};
    in {devShell = haskellLib.mkShell haskellProjectConfigs;});
}
