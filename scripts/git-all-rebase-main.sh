#!/usr/bin/env bash

# ==============================================================================
# Options to customize dialog display

NITEMS_TO_SHOW=20
NCOLS="$(@tput@ cols)"
[ "$NCOLS" -gt 80 ] && NCOLS=80

NLINES="$(@tput@ lines)"
[ "$NLINES" -gt 18 ] && NLINES=18

# ==============================================================================

username=ndam
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

branches=()

OLDIFS="$IFS"
IFS='#'
echo "Will execute the following branches:"
for cmd in ${branches_out_of_date[@]}; do
  cmd="${cmd#$'\n'}"
  branches+=("$cmd")
  echo "- $cmd"
done
IFS="$OLDIFS"

if command -v @dialog@ &>/dev/null; then
  checklist_args=(--separate-output
    --no-tags
    --stdout
    --backtitle 'Git branch mass-rebase'
    --checklist 'Please select the branches to rebase'
    "$NLINES" "$NCOLS" "$NITEMS_TO_SHOW")
  for branch in "${branches[@]}"; do
    checklist_args+=("$branch" "$branch" on)
  done

  branches=($(@dialog@ "${checklist_args[@]}"))
  clear
fi

for branch in "${branches[@]}"; do
  git rebase-main --no-fetch "$@" "${branch//\'/}"
done
