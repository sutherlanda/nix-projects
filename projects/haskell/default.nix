{ pkgs, haskellPackages ? p: [ ] }:

let

  hie-program = pkgs.writeShellScriptBin "hie-program" ''
    test -z "$HIE_BIOS_OUTPUT" && echo "Invalid HIE_BIOS_OUTPUT environment variable" && exit 1
    test -f "$HIE_BIOS_OUTPUT" && rm "$HIE_BIOS_OUTPUT"
    touch "$HIE_BIOS_OUTPUT"
    cd src
    find . -iname '*.hs' -exec bash -c 'echo "$(dirname $1)/$(basename $1 .hs)" >> "$HIE_BIOS_OUTPUT"' bash {} \;
  '';

  hie-gen = pkgs.writeShellScriptBin "hie-gen" ''
    echo -ne "cradle: {bios: {program: "${hie-program}/bin/hie-program"}}" > "src/hie.yaml"
  '';

  # https://github.com/NixOS/nixpkgs/issues/140774#issuecomment-976899227
  rootGhcPkg =
    pkgs.haskell.packages.ghc8107.override {
      overrides = self: super:
        let
          workAround140774 = hpkg: with pkgs.haskell.lib;
            overrideCabal hpkg (drv: {
              enableSeparateBinOutput = false;
            });
        in
        {
          ghcid = workAround140774 super.ghcid;
          ormolu = workAround140774 super.ormolu;
          hls = workAround140774 super.haskell-language-server;
        };
    };

  shellHook = ''
    hie-gen
  '';

  mkShell = pkgs.mkShell {
    inherit shellHook;
    buildInputs = [
      (rootGhcPkg.ghcWithPackages haskellPackages)
      rootGhcPkg.ghcid
      rootGhcPkg.hls
      rootGhcPkg.ormolu
      hie-gen
    ];
  };

in

{
  inherit mkShell;
}

