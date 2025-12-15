# Compatibility shim for non-flake commands
# Allows using: nix-build, nix-env, etc.
(import (
  let
    lock = builtins.fromJSON (builtins.readFile ./flake.lock);
    nodeName = lock.nodes.root.inputs.flake-compat or "flake-compat";
    node = lock.nodes.${nodeName};
    locked = node.locked;
  in
  fetchTarball {
    url = "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.tar.gz";
    sha256 = locked.narHash;
  }
) { src = ./.; }).defaultNix
