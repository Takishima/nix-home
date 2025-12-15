# treefmt configuration
{ pkgs, ... }:
{
  projectRootFile = "flake.nix";

  programs = {
    # Nix formatting
    nixfmt = {
      enable = true;
      package = pkgs.nixfmt-rfc-style;
    };

    # Markdown formatting
    mdformat.enable = true;

    # Shell script formatting
    shfmt.enable = true;

    # TOML formatting
    taplo.enable = true;

    # YAML formatting
    yamlfmt.enable = true;

    # JSON formatting
    prettier = {
      enable = true;
      includes = [ "*.json" ];
    };
  };
}
