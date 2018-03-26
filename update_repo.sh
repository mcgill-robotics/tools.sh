#!/bin/bash
#
# McGill Robotics Repository Updater.
#
# Updates a repository quasi-safely.
#

# Get path to repository.
DIR="$(git rev-parse --show-toplevel)"

# Color codes.
QUESTION="$(tput bold; tput setaf 4)"
WARNING="$(tput bold; tput setaf 1)"
RESET="$(tput sgr0)"

if [[ -z "$(git status -s)" ]]; then
  # Only attempt updating if there are no uncommitted local changes and if
  # the current branch is being tracked remotely.
  local_branch=$(git rev-parse --abbrev-ref HEAD)
  remote_branch=$(
    git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2> /dev/null || :)

  if [[ -z ${remote_branch} ]]; then
    echo -n "${WARNING}${DIR}'s ${local_branch} branch isn't tracked: "
    echo "skipping...${RESET}"
  else
    git fetch origin "${local_branch}"
    ahead_count=$(git rev-list --count FETCH_HEAD..HEAD)
    behind_count=$(git rev-list --count HEAD..FETCH_HEAD)

    if [[ "${behind_count}" == "0" ]]; then
      # No remote changes, so we can skip.
      :
    elif [[ "${ahead_count}" == "0" ]]; then
      # No local changes, so we can safely update.
      git reset --hard "${remote_branch}"
      git submodule sync --recursive
      git submodule update --init --recursive --force
    else
      # It is uncertain whether a merge will lead to conflicts, so the user
      # should do the reset manually.
      echo -n "${WARNING}${DIR}'s ${local_branch} branch is ${ahead_count} "
      echo "commits ahead and ${behind_count} commits behind remote${RESET}"

      echo "Updating automatically will lose any local changes in ${DIR})"
      echo -n "${QUESTION}Do you wish to hard reset to remote?${RESET}"
      echo -n " [y/N] (default no) "
      read hard_reset
      case "${hard_reset}" in
        y|Y )
          echo "${WARNING}Running: git reset --hard ${remote_branch}${RESET}"
          git reset --hard "${remote_branch}"
          git submodule sync --recursive
          git submodule update --init --recursive --force
          ;;
        * )
          echo -n "${WARNING}Not hard resetting...${RESET} "
          echo "Remember to update manually"
          ;;
      esac
    fi
  fi
else
  echo "${WARNING}Found uncommitted changes in ${DIR}: skipping...${RESET}"
fi

