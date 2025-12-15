# Example user configuration template
# Copy this file and customize for new users
#
# Usage:
# 1. Copy this file: cp example.nix username.nix
# 2. Update all values below
# 3. Add to flake.nix:
#    "username" = mkUser { modules = [ ./users/username.nix ]; };
# 4. Build: home-manager build --flake .#username
# 5. Switch: home-manager switch --flake .#username
{ ... }:

{
  my = {
    # ==================== REQUIRED: User Identity ====================
    user = {
      name = "newuser"; # Your Unix username
      fullName = "New User"; # Your full name (for git commits)
      email = "user@example.com"; # Your email address
      homeDirectory = "/home/newuser"; # Your home directory
    };

    # ==================== OPTIONAL: Git Configuration ====================
    git = {
      # SSH public key for commit signing (leave null to disable signing)
      # Get your key from: cat ~/.ssh/id_ed25519.pub
      signingKey = null;

      # GitLab username (leave null if not using GitLab)
      gitlabUser = null;
    };

    # ==================== OPTIONAL: NVIDIA GPU Support ====================
    # Enable if you have an NVIDIA GPU and want hardware acceleration
    nvidia = {
      enable = false;

      # To find your driver version:
      # nvidia-smi --query-gpu=driver_version --format=csv,noheader
      # driverVersion = "565.57.01";

      # To get the hash:
      # nix-prefetch-url https://download.nvidia.com/XFree86/Linux-x86_64/${VERSION}/NVIDIA-Linux-x86_64-${VERSION}.run
      # driverHash = "sha256-...";
    };

    # ==================== OPTIONAL: 1Password Integration ====================
    # Enable for SSH agent and git signing via 1Password
    onePassword = {
      enable = false;
      # agentSocket = "~/.1password/agent.sock";  # Default value
    };

    # ==================== OPTIONAL: GNOME Desktop Integration ====================
    # Enable for custom keybindings (tdrop dropdown terminal, emacs-multiscreen)
    gnome.enable = false;

    # ==================== OPTIONAL: Hexagon Work Configuration ====================
    # Enable ONLY if you work at Hexagon on the Paragon project
    work.hexagon = {
      enable = false;
      # paragonRoot = "$HOME/code/hexagon/paragon";
      # isaacRosWs = "/home/user/workspaces/isaac_ros-dev/";
      # gitSafeDirectories = [];
      # gitMaintenanceRepos = [];
    };

    # ==================== Profiles (Feature Bundles) ====================
    profiles = {
      # Base profile: essential CLI tools, shell config, starship, direnv
      # Almost always want this enabled
      base = true;

      # Development profile: git, dev tools, language servers, cloud tools
      # Enable if you're doing software development
      development = true;
    };
  };
}
