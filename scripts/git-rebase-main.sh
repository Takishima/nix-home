#!/usr/bin/env bash

set -eETuo pipefail

# ==============================================================================

if [ -z "${TERM-}" ]; then
  TERM="xterm-256color"
fi
_color_txt_body() {
  set +u
  #if there are args, we operate in normal mode, but we don't like
  if [[ -n ${1-} ]]; then # &&  "$1" != "+" ]]
    echo -n "$@"
    @tput@ -T$TERM sgr0 || true #reset to default color
  #else, if we have no args, and we assume we are attached to a pipe
  elif [[ ! -t 0 ]]; then
    # read text from pipe
    cat                         # read from stdin
    @tput@ -T$TERM sgr0 || true #reset to default color
  fi
  set -u
}
bold_yellow() {
  @tput@ -T"$TERM" setaf 3 bold || true
  _color_txt_body "$@"
}

# ==============================================================================

do_fetch=1
do_push=0
do_pull=0
while [ ! -z "${1-}" ]; do
  if [[ -n ${1:-} && ${1:-} == "--pull" ]]; then
    do_pull=1
  elif [[ -n ${1:-} && ${1:-} == "--push" ]]; then
    do_push=1
  elif [[ -n ${1:-} && ${1:-} == "--no-fetch" ]]; then
    do_fetch=0
  else
    if ! @git@ rev-parse "${1:-}" &>/dev/null; then
      echo "${1:-} is not a Git branch!" 1>&2
      exit 128
    else
      @git@ checkout "${1:-}"
    fi
  fi
  shift
done

current_branch="$(@git@ branch --show-current)"

echo "Currently on branch: $current_branch"

if ! @git@ diff-index --quiet HEAD; then
  bold_yellow -e "Cannot rebase with unstaged/staged changes."
  exit 1
fi

if [ $do_fetch -eq 1 ]; then
  echo 'Fetching all remotes'
  @git@ fetch --all
fi

echo "Checking out branch: $current_branch"
@git@ checkout "$current_branch"

echo "Rebasing branch $current_branch onto main"
@git@ rebase main && result=0 || result=1

while [ "$result" -eq 1 ]; do
  bold_yellow -e "Rebase conflict detected. I will open a sub-shell for you.\n"
  bold_yellow -e "Please solve the current issues and close the shell. The rebasing process will continue afterwards\n"
  bold_yellow -e "If you wish to abort the rebasing process, simply exit the subshell with a non-zero return code (e.g. exit 1)\n"
  if "$SHELL"; then
    @git@ rebase --continue && result=0 || result=1
  else
    exit 1
  fi
done

if [ "$do_push" -eq 1 ]; then
  echo 'Pushing branch to GitLab'
  @git@ push --no-verify --force-with-lease --force-if-includes gitlab
fi
