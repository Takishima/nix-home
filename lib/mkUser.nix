# Factory function to create Home Manager user configurations
{ inputs }:

{
  mkUser =
    {
      system ? "x86_64-linux",
      modules ? [ ],
      overlays ? [ ],
    }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (import ../overlays { inherit inputs; })
        ]
        ++ overlays;
      };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        # sops-nix home-manager module
        inputs.sops-nix.homeManagerModules.sops
        # Custom modules
        ../modules/profiles/core.nix
        ../modules/profiles/base.nix
        ../modules/profiles/shell.nix
        ../modules/profiles/terminal.nix
        ../modules/profiles/prompt.nix
        ../modules/profiles/git.nix
        ../modules/profiles/development.nix
        ../modules/profiles/emacs.nix
        ../modules/profiles/nvidia.nix
        ../modules/profiles/ros2.nix
        ../modules/profiles/onepassword.nix
        ../modules/profiles/plotting.nix
        ../modules/profiles/nix.nix
        ../modules/profiles/sops.nix
        ../modules/profiles/help.nix
        ../modules/profiles/etc-managed
        ../modules/profiles/peripherals.nix
      ]
      ++ modules;
    };
}
