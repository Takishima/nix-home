# Compatibility shim for nix-shell
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
) { src = ./.; }).shellNix
