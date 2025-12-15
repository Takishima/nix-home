# overlays/default.nix
{ inputs, ... }:

let
  inherit (inputs.nixpkgs) lib;

  # Import individual overlay files
  overlays = [
    (import ./nix-output-monitor.nix)
    (import ./mcp-pypi.nix)
    (import ./bash-language-server.nix)
    (import ./emacs-lsp-booster.nix)
    inputs.nixgl.overlay
  ];
in
lib.fixedPoints.composeManyExtensions overlays
