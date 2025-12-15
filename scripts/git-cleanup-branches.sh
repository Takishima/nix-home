#!/usr/bin/env bash

# Bash script that cleans up local branches that are not present in any Git remote

# ==============================================================================
# Options to customize dialog display

NITEMS_TO_SHOW=10
NCOLS="$(@tput@ cols)"
[ "$NCOLS" -gt 80 ] && NCOLS=80

NLINES="$(@tput@ lines)"
[ "$NLINES" -gt 18 ] && NLINES=18

# ==============================================================================

local_branches=$(@git@ for-each-ref --format='%(refname:short)' refs/heads/)
remotes=$(@git@ remote)
remote_branches=$(@git@ branch -a | @grep@ "$remote" || true)

echo "Fetching all remotes"
@git@ fetch --all

branches_to_remove=()
for branch in $local_branches; do
  found=0
  echo "Processing $branch"
  for remote in $remotes; do
    remote_branch="remotes/$remote/$branch"
    if @git@ rev-parse --verify "${remote_branch}" &>/dev/null; then
      found=1
    fi
  done
  if [ "$found" -eq 0 ]; then
    branches_to_remove+=($branch)
  fi
done

[ -z "${branches_to_remove[*]}" ] && exit 0

if command -v @dialog@ &>/dev/null; then
  checklist_args=(--separate-output
    --no-tags
    --stdout
    --backtitle 'Git branch cleanup'
    --checklist 'Please select the branches to delete'
    "$NLINES" "$NCOLS" "$NITEMS_TO_SHOW")
  for branch in "${branches_to_remove[@]}"; do
    checklist_args+=("$branch" "$branch" on)
  done

  branches_to_remove=($(@dialog@ "${checklist_args[@]}"))
  clear
else
  echo 'Will be removing the following branches:'
  for branch in "${branches_to_remove[@]}"; do
    echo " - $branch"
  done

  echo 'Do CTRL+C to cancel, ENTER to accept'
  read -r a
fi

if [ -n "${branches_to_remove[*]}" ]; then
  for branch in "${branches_to_remove[@]}"; do
    worktree="$(@git@ worktree list --porcelain | @grep@ -B2 "^branch refs/heads/$branch" | @head@ -1 | @cut@ -d' ' -f 2)"
    if [ -n "$worktree" ]; then
      @git@ worktree remove --force "$worktree"
    fi
  done
  @git@ branch -D "${branches_to_remove[@]}"
fi
