# Override nix-output-monitor to use master branch with local patches
final: prev: {
  nix-output-monitor = prev.nix-output-monitor.overrideAttrs (old: {
    src = prev.fetchFromGitHub {
      owner = "maralorn";
      repo = "nix-output-monitor";
      rev = "0cb46615fb8187e4598feac4ccf8f27a06aae0b7"; # master as of 2025-11-28
      hash = "sha256-iEvbCIlHX6WUblrnoF7gwUQtu2ay97zoZsvoP85I2BA=";
    };
    patches = (old.patches or [ ]) ++ [
      ./0001-fix-Resolve-finished-process-issue.patch
    ];
  });
}
