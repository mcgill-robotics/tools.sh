#!/bin/bash
#
# McGill Robotics Code Linter.
#
# Lints the current repository with catkin_lint while ignoring submodules and
# any errors defined in a .lintignore file at the root of the repository.
#
# shellcheck disable=SC2010,SC2086
#

# Exit on first error.
set -e

# Get directory of this repository.
DIR="$(git rev-parse --show-toplevel)"
if [[ ! -d "${DIR}/catkin_ws/src" ]]; then
  >&2 echo "could not find catkin_ws in ${DIR}"
  exit 1
fi
pushd "${DIR}" > /dev/null

# Get all submodule paths.
if [[ -f .gitmodules ]]; then
  SUBMODULE_PATHS="$(grep "path" .gitmodules | sed 's/.*= //')"
else
  SUBMODULE_PATHS=
fi

# Get all non-submodule packages.
NON_SUBMODULE_PACKAGES="$(
  ls -d catkin_ws/src/*/ |
    grep -v "${SUBMODULE_PATHS}"
)"

# Find errors to ignore.
if [[ -f .lintignore ]]; then
  LINT_ARGS="$(sed -e 's/^/--ignore /' .lintignore | tr '\n' ' ')"
else
  LINT_ARGS=
fi

catkin lint --explain -W2 --strict ${NON_SUBMODULE_PACKAGES} ${LINT_ARGS}

