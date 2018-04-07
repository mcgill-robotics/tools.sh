#!/bin/bash
#
# McGill Robotics Repository Syncer
#
# Syncs the repository and its submodules with any machine on the local area
# network that is accessible by SSH.
#

# Exit on first error.
set -e

# Default arguments.
MACHINE=
COMMAND=
ARGS=
ROOT=repos
SKIP_SSH=false

function print_usage {
  echo "usage: sync.sh [init|fetch|push|pull] <machine> [-h | --help] -- <args>"
  echo
  echo "McGill Robotics Repository Syncer."
  echo
  echo "This script allows one to easily sync this repository and its"
  echo "submodules with any machine on a local network in the event an internet"
  echo "connection is unavailable. The only constraint is that you must be able"
  echo "to SSH into the target machine."
  echo
  echo "commands:"
  echo "  init                  setup target machine and remote repositories"
  echo "  fetch                 fetch remote changes"
  echo "  push                  push local changes"
  echo "  pull                  pull remote changes"
  echo
  echo "required arguments:"
  echo "  machine               target machine to connect to as user@host"
  echo
  echo "optional arguments:"
  echo "  -h, --help            show this help message and exit"
  echo "  --root                root directory for all repositories on target"
  echo "                        only used by init command (default: repos)"
  echo "  --skip-ssh            skip remote SSH setup"
  echo "                        only used by init command"
  echo "  -- <args>             additional arguments to pass to git"
  echo "                        only used by push, pull and fetch commands"
}

# Parse arguments.
REACHED_END=false
while [[ "${#}" -gt 0 && ${REACHED_END} == false ]]; do
  case "${1}" in
    -h | --help )
      print_usage
      exit 0
      ;;
    --root )
      if [[ "${#}" -gt 1 ]]; then
        ROOT="${2}"
        shift  # skip next argument
      else
        >&2 echo 'error: no root was specified'
        exit 1
      fi
      ;;
    --skip-ssh )
      SKIP_SSH=true
      ;;
    init | fetch | pull | push )
      if [[ -z ${COMMAND} ]]; then
        COMMAND="${1}"
      else
        >&2 echo 'error: only one command can be specified at a time'
        exit 1
      fi

      if [[ "${#}" -gt 1 ]]; then
        MACHINE="${2}"
        shift  # skip next argument
      else
        >&2 echo 'error: no machine was specified'
        exit 1
      fi
      ;;
    -- )
      REACHED_END=true
      if [[ "${#}" -gt 1 ]]; then
        shift  # skip --
        ARGS="${*}"  # save all the rest
      fi
      ;;
    * )
      >&2 echo "error: unrecognized argument ${1}"
      exit 1
      ;;
  esac

  shift
done

if [[ -z ${COMMAND} ]]; then
  >&2 echo 'error: no command was specified'
  exit 1
fi

function _get_default_url {
  local url
  url="$(git remote get-url origin)"
  if echo "${url}" | grep -q '@'; then
    # Assume SSH.
    # Get the path after git@gitub.com:
    url="${url//*:/}"
  else
    # Assume HTTPS-like.
    # Get the last 2 '/'-surrounded fields
    url="$(echo "${url}" | rev | cut -d/ -f1-2 | rev)"
  fi

  # Append .git
  if [[ "${url}" != *.git ]]; then
    url="${url}.git"
  fi

  echo "${url}"
}

function _set_remote {
  # Remove any previous remote.
  git remote remove "${MACHINE}" 2> /dev/null || :

  # Add new remote.
  if [[ -z "${ROOT// }" ]]; then
    git remote add "${MACHINE}" "${MACHINE}:$(_get_default_url)"
  else
    git remote add "${MACHINE}" "${MACHINE}:${ROOT}/$(_get_default_url)"
  fi
}

function _get_branch {
  # TODO: should ideally use the current branch in the event there are multiple
  #       branches that contain HEAD.
  git branch --contains HEAD |
    grep -v 'HEAD detached at' |  # Ignore detached heads
    sed -e 's/\* //' |  # Remove preceding star
    sed -e 's/^[[:space:]]*//' |  # Remove leading spaces
    head -n 1  # Pick first one
}

function _sync {
  if [[ "${COMMAND}" == "push" ]]; then
    git ${COMMAND} "${MACHINE}" --all ${ARGS}
  else
    git ${COMMAND} "${MACHINE}" "$(_get_branch)" ${ARGS}
  fi
}

# Get directory of this repository.
DIR="$(git rev-parse --show-toplevel)"
pushd "${DIR}" > /dev/null

# Get all submodule paths.
if [[ -f "${DIR}/.gitmodules" ]]; then
  SUBMODULE_PATHS="$(grep "path" "${DIR}/.gitmodules" | sed 's/.*= //')"
  SUBMODULE_URLS="$(
    grep "url" "${DIR}/.gitmodules" |
      sed 's/.*://' |
      tr '\n' ' '
  )"
else
  SUBMODULE_PATHS=""
  SUBMODULE_URLS=""
fi

if [[ "${COMMAND}" == "init" ]]; then
  # Set up target machine.
  if [[ ${SKIP_SSH} == true ]]; then
    echo "Skipping target machine setup"
  else
    echo "Setting up target machine..."
    ROOT_URL="$(_get_default_url)"
    ssh "${MACHINE}" "
      # Set up bare root repository.
      mkdir -p \"${ROOT}/${ROOT_URL}\"
      pushd \"${ROOT}/${ROOT_URL}\"
      git init --bare
      popd

      # Set up bare repository for each submodule.
      for submodule in ${SUBMODULE_URLS}; do
        mkdir -p \"${ROOT}/\${submodule}\" > /dev/null
        pushd \"${ROOT}/\${submodule}\"
        git init --bare
        popd
      done

      # Configure all git repositories to point to the local bare repositories.
      # NOTE: Order matters.
      pushd \"${ROOT}\"
      git config --global --replace-all \
        url.\"git@github.com:\".insteadOf 'https://github.com/'
      git config --global --replace-all \
        url.\"\${PWD}/\".insteadOf 'git@github.com:'
      popd
    "
    echo
  fi

  echo "Setting root repository remote..."
  _set_remote

  for submodule in ${SUBMODULE_PATHS}; do
    echo "Setting ${submodule} remote..."
    pushd "${submodule}" > /dev/null
    _set_remote
    popd > /dev/null
  done
else
  case "${COMMAND}" in
    fetch )
      VERB="Fetching"
      ;;
    pull )
      VERB="Pulling"
      ;;
    push )
      VERB="Pushing"
      ;;
    * )
      VERB="Syncing"
      ;;
  esac

  echo "${VERB} root repository..."
  _sync

  # Set up submodules.
  for submodule in ${SUBMODULE_PATHS}; do
    echo "${VERB} ${submodule}..."
    pushd "${submodule}" > /dev/null
    _sync
    popd > /dev/null
  done
fi
