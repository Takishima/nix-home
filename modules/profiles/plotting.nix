# Plotting tools
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my;
in
{
  config = lib.mkIf cfg.profiles.plotting {
    home.packages = with pkgs; [
      gnuplot
    ];
  };
}
