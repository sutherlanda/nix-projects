{
  pkgs,
  haskellPackages ? p: [],
}: let
  makeProject = projectConfig: {
    name = projectConfig.name;
    hieGen = hieGen projectConfig;
    shellHook = "${projectConfig.name}-hie-gen";
    buildCmds = makeBuildCmds projectConfig;
    runCmds = makeRunCmds projectConfig;
    watchCmds = makeWatchCmds projectConfig;
    ghci = makeGhciCmd projectConfig;
  };

  hieGen = projectConfig:
    pkgs.writeShellScriptBin "${projectConfig.name}-hie-gen" ''
      if [[ -d "${projectConfig.srcDir}" ]]
      then
        echo -ne "cradle: {bios: {program: "${hieProgram projectConfig}/bin/${projectConfig.name}-hie-gen"}}" > "${projectConfig.srcDir}/hie.yaml"
      fi
    '';

  makeFlags = projectConfig: sep:
    builtins.concatStringsSep sep
    (builtins.concatLists [
      ["-no-user-package-db" "-i=${projectConfig.srcDir}"]
    ]);

  hieProgram = projectConfig:
    pkgs.writeShellScriptBin "${projectConfig.name}-hie-gen" ''
      test -z "$HIE_BIOS_OUTPUT" && echo "Invalid HIE_BIOS_OUTPUT environment variable" && exit 1
      test -f "$HIE_BIOS_OUTPUT" && rm "$HIE_BIOS_OUTPUT"
      touch "$HIE_BIOS_OUTPUT"
      cd ${projectConfig.srcDir}
      echo -e "${makeFlags projectConfig "\\n"}" >> $HIE_BIOS_OUTPUT
      find . -iname '*.hs' -exec bash -c 'echo "$(dirname $1)/$(basename $1 .hs)" >> "$HIE_BIOS_OUTPUT"' bash {} \;
    '';

  makeBuildDir = projectRoot: executableName: "${projectRoot}/build/${executableName}";

  makeBuildArtifactsDir = projectRoot: executableName: "${projectRoot}/artifacts/${executableName}";

  makeBuildTarget = projectRoot: executableName: "${makeBuildDir projectRoot executableName}/out.ghc";

  makeGhciCmd = projectConfig:
    pkgs.writeShellScriptBin "${projectConfig.name}-ghci" ''
      ghci -i=${projectConfig.srcDir} "$@"
    '';

  makeBuildCmds = projectConfig: let
    makeCmd = execName: execTarget:
      pkgs.writeShellScriptBin "${projectConfig.name}-${execName}-build" ''
        mkdir -p ${makeBuildDir projectConfig.projectRoot execName}
        ghc \
          -i=${projectConfig.srcDir} ${projectConfig.srcDir}/${execTarget} \
          -odir ${makeBuildDir projectConfig.projectRoot execName} \
          -hidir ${makeBuildArtifactsDir projectConfig.projectRoot execName} \
          -o ${makeBuildTarget projectConfig.projectRoot execName}
          "$@"
      '';
  in
    builtins.mapAttrs makeCmd projectConfig.executables;

  makeWatchCmds = projectConfig: let
    makeCmd = execName: execTarget:
      pkgs.writeShellScriptBin "${projectConfig.name}-${execName}-watch" ''
        ghcid \
          --command="${projectConfig.name}-ghci" \
          --test=main \
          --reload="${projectConfig.srcDir}" \
          "${projectConfig.srcDir}/${execTarget}" \
          "$@"
      '';
  in
    builtins.mapAttrs makeCmd projectConfig.executables;

  makeRunCmds = projectConfig: let
    makeCmd = execName: execTarget:
      pkgs.writeShellScriptBin "${projectConfig.name}-${execName}-run" ''
        if [[ -f ${makeBuildTarget projectConfig.projectRoot execName} ]]
        then
          ${makeBuildTarget projectConfig.projectRoot execName} "$@"
        fi
      '';
  in
    builtins.mapAttrs makeCmd projectConfig.executables;

  # https://github.com/NixOS/nixpkgs/issues/140774#issuecomment-976899227
  #rootGhcPkg = pkgs.ghc.override {
  #overrides = self: super: let
  #workAround140774 = hpkg:
  #with pkgs.haskell.lib;
  #overrideCabal hpkg (drv: {
  #enableSeparateBinOutput = false;
  #});
  #in {
  #ghcid = workAround140774 super.ghcid;
  #ormolu = workAround140774 super.ormolu;
  #hls = workAround140774 super.haskell-language-server;
  #};
  #};

  mkShell = projectConfigs: let
    projects = map makeProject projectConfigs;
  in
    pkgs.mkShell {
      shellHook = builtins.concatStringsSep "\\n" (map (project: project.shellHook) projects);
      buildInputs = builtins.concatLists [
        (map (p: p.hieGen) projects)
        (map (p: p.ghci) projects)
        (builtins.concatLists (map builtins.attrValues (map (p: p.buildCmds) projects)))
        (builtins.concatLists (map builtins.attrValues (map (p: p.runCmds) projects)))
        (builtins.concatLists (map builtins.attrValues (map (p: p.watchCmds) projects)))
        [
          (pkgs.haskellPackages.ghcWithPackages haskellPackages)
          pkgs.haskellPackages.ghcid
          #pkgs.haskellPackages.hls
          pkgs.haskellPackages.ormolu
        ]
      ];
    };
in {
  inherit mkShell;
}
