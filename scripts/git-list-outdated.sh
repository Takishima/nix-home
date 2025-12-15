#!/usr/bin/env bash

set -Eeuo pipefail

# Bash script that lists local branches that are out of date with main

username=${1:-ndam}
worktree_branches="$(@git@ worktree list --porcelain | @grep@ branch | @cut@ -d ' ' -f2 | @sed@ 's|refs/heads/||' | @sort@)"
local_branches="$(@git@ for-each-ref --format='%(refname:short)' refs/heads/ | @grep@ "$username" | @sort@)"
branches_to_process="$(@comm@ -23 <(echo "$local_branches") <(echo "$worktree_branches"))"

if @git@ rev-parse gitlab/main &>/dev/null; then
  main_hash="$(@git@ rev-parse gitlab/main)"
else
  main_hash="$(@git@ rev-parse origin/main)"
fi

branches_out_of_date=()
for branch in $branches_to_process; do
  if [[ "$(@git@ merge-base main "$branch")" != "$main_hash" ]]; then
    branches_out_of_date+=("$branch")
  fi
done

[ -z "${branches_out_of_date[*]}" ] && exit 0

echo 'The following branches are out of date:'
for branch in "${branches_out_of_date[@]}"; do
  echo " - $branch"
done
