# Override emacs-lsp-booster to use master branch
final: prev: {
  emacs-lsp-booster = prev.emacs-lsp-booster.overrideAttrs (old: rec {
    version = "unstable-2025-11-29";
    src = prev.fetchFromGitHub {
      owner = "blahgeek";
      repo = "emacs-lsp-booster";
      rev = "8059c7dce8f9abe26099f6e30e7824c63c5ebd79"; # master as of 2025-11-29
      hash = "sha256-++YkiKyJhjynPTntHcF/PLsnQj2/enZwXe/F0mQ73vg=";
    };
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      inherit src;
      hash = "sha256-7lIceMT2hJplHU2VIN1O8IiGE6+DxO4/uM8pYS/qvlE=";
    };
  });
}
