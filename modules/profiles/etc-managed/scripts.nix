# hm-sys command - unified interface for managed system files
{
  config,
  pkgs,
  ...
}:

let
  cfg = config.my.etc;
  stagingDir = "${config.home.homeDirectory}/${cfg.stagingDir}";

  hm-sys = pkgs.stdenv.mkDerivation {
    name = "hm-sys";
    src = ./hm-sys.sh;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/bin
      substitute $src $out/bin/hm-sys \
        --replace-fail '@STAGING_DIR@' '${stagingDir}' \
        --replace-fail '@JQ@' '${pkgs.jq}/bin/jq' \
        --replace-fail '@DIFFUTILS@' '${pkgs.diffutils}' \
        --replace-fail '@BAT@' '${pkgs.bat}' \
        --replace-fail '@COREUTILS@' '${pkgs.coreutils}'
      chmod +x $out/bin/hm-sys
    '';
  };
in
{
  inherit hm-sys;
}
