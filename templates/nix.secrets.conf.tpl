# Secrets for nix.conf - injected via 1Password
# This file is included from ~/.config/nix/nix.conf
access-tokens = github.com={{ op://Employee/GitHub PAT devenv CLI/token }} gitlab.com=PAT:{{ op://Employee/GitLab do-all PAT/token }}
