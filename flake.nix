{
  description = "Multi-user Home Manager configuration with optional features";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # For compatibility with non-flake commands
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    # External flakes
    cachix = {
      url = "github:cachix/cachix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index = {
      url = "github:nix-community/nix-index";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-update = {
      url = "github:Mic92/nix-update";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nil = {
      url = "github:Takishima/nil/impure-flake-show";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rime = {
      url = "github:lukasl-dev/rime";
      # Don't follow our nixpkgs - let it use its own pinned version
      # to avoid rust nightly compatibility issues
    };

    nix-ai-tools = {
      url = "github:numtide/nix-ai-tools";
      # Don't follow our nixpkgs - let it use its own pinned version
      # to avoid rust nightly compatibility issues
    };

    # Using upstream packages with local patches via overlays:
    # - mcp-pypi: overlays/mcp-pypi.nix
    # - nix-output-monitor: overlays/nix-output-monitor.nix

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      treefmt-nix,
      ...
    }@inputs:
    let
      # Support both x86_64-linux and aarch64-linux
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Helper to apply a function to all systems
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Create pkgs for each system
      pkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ (import ./overlays { inherit inputs; }) ];
        }
      );

      # Import the mkUser helper
      lib = import ./lib { inherit inputs; };
      inherit (lib) mkUser;
    in
    {
      # User configurations
      homeConfigurations = {
        # Damien - full configuration with all features enabled
        "damien" = mkUser {
          modules = [ ./users/damien.nix ];
        };

        # Add more users here:
        # "alice" = mkUser {
        #   modules = [ ./users/alice.nix ];
        # };
      };

      # For convenience: nix fmt
      formatter = forAllSystems (
        system: (treefmt-nix.lib.evalModule pkgsFor.${system} ./treefmt.nix).config.build.wrapper
      );

      # For CI: nix flake check
      checks = forAllSystems (system: {
        formatting = (treefmt-nix.lib.evalModule pkgsFor.${system} ./treefmt.nix).config.build.check self;
      });

      packages = forAllSystems (system: {
        default = self.homeConfigurations.damien.activationPackage;
        homeManagerConfiguration = self.homeConfigurations.damien.activationPackage;
      });
    };
}
