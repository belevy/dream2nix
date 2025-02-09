{
  config,
  lib,
  options,
  ...
}: let
  l = lib // builtins;
  cfg = config.nixpkgs-overrides;

  exclude =
    l.genAttrs cfg.exclude (name: null);

  extractOverrideAttrs = overrideFunc:
    (overrideFunc (old: {passthru.old = old;}))
    .old;

  extractPythonAttrs = pythonPackage: let
    pythonAttrs = extractOverrideAttrs pythonPackage.overridePythonAttrs;
  in
    l.filterAttrs (name: _: ! exclude ? ${name}) pythonAttrs;

  extracted =
    if config.deps.python.pkgs ? ${config.name}
    then extractPythonAttrs config.deps.python.pkgs.${config.name}
    else {};

  extractedMkDerivation =
    l.intersectAttrs
    options.mkDerivation
    extracted;

  extractedBuildPythonPackage =
    l.intersectAttrs
    options.buildPythonPackage
    extracted;

  extractedEnv =
    l.filterAttrs
    (
      name: _:
        ! (
          extractedMkDerivation
          ? ${name}
          || extractedBuildPythonPackage ? ${name}
        )
    )
    extracted;
in {
  imports = [
    ./interface.nix
  ];

  config = l.mkMerge [
    (l.mkIf cfg.enable {
      mkDerivation = extractedMkDerivation;
      buildPythonPackage = extractedBuildPythonPackage;
      env = extractedEnv;
    })
    {
      nixpkgs-overrides.lib = {inherit extractOverrideAttrs extractPythonAttrs;};
      nixpkgs-overrides.exclude = [
        "all"
        "args"
        "builder"
        "name"
        "pname"
        "version"
        "src"
        "outputs"
      ];
    }
  ];
}
