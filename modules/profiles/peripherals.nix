# Peripherals profile
# 3D printing and label printer tools
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.my.peripherals;
in
{
  options.my.peripherals = {
    enable3dPrinting = mkEnableOption "3D printing tools (PrusaSlicer)";
    enableLabelPrinter = mkEnableOption "Brother P-Touch label printer support";
  };

  config = mkMerge [
    # 3D printing tools (PrusaSlicer)
    (mkIf cfg.enable3dPrinting {
      home.packages = [ pkgs.prusa-slicer ];
    })

    # Brother P-Touch label printer support
    (mkIf cfg.enableLabelPrinter {
      home.packages = [ pkgs.ptouch-print ];
    })
  ];
}
