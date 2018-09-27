#!/bin/bash
#
# McGill Robotics Code Formatter
#
# Formats all Python and C++ code in the repository with YAPF and clang-format.
#
# shellcheck disable=SC2086
#

# Default arguments.
DRY_RUN=false
CHANGES_ONLY=false
STAGING_ONLY=false
REVISION="origin/dev"
PACKAGE=""
FORMAT_PYTHON=true
FORMAT_CPP=true
VERBOSE=false

function print_usage {
  echo "usage: format.sh [-h | --help] [--dry-run] [--package PACKAGE]"
  echo "                 [--staging-only | --changes-only [REV]]"
  echo
  echo "McGill Robotics Code Formatter."
  echo
  echo "optional arguments:"
  echo "  -h, --help            show this help message and exit"
  echo "  --version             print the version of the formatters and exit"
  echo "  --dry-run             print diffs instead of modifying in place"
  echo "  --package PACKAGE     format a single package instead of all"
  echo "  --staging-only        only format staged files"
  echo "                        cannot be used with --changes-only"
  echo "  --changes-only [REV]  only format files changed against REV"
  echo "                        default revision REV is origin/dev"
  echo "                        cannot be used with --staging-only"
  echo "  --cpp-only            only format C++ files with clang-format"
  echo "                        cannot be used with --python-only"
  echo "  --python-only         only format Python files with YAPF"
  echo "                        cannot be used with --cpp-only"
  echo "  --verbose             print additional information"
}

# Get directory of this repository.
DIR="$(git rev-parse --show-toplevel)"


# Parse arguments.
while [[ "${#}" -gt 0 ]]; do
  case "${1}" in
    --dry-run )
      DRY_RUN=true
      ;;
    --verbose )
      VERBOSE=true
      ;;
    --staging-only )
      STAGING_ONLY=true
      ;;
    --changes-only )
      CHANGES_ONLY=true
      if [[ "${#}" -gt 1 ]]; then
        REVISION="${2}"
        shift  # skip next argument
      fi
      ;;
    --package )
      if [[ "${#}" -gt 1 ]]; then
        PACKAGE="${2}"
        shift  # skip next argument
        if [[ ! -d "${DIR}/catkin_ws/src/${PACKAGE}" ]]; then
          >&2 echo "could not find package: ${PACKAGE}"
          exit 2
        fi
      else
        print_usage
        exit 1
      fi
      ;;
    --cpp-only )
      FORMAT_PYTHON=false
      ;;
    --python-only )
      FORMAT_CPP=false
      ;;
    --version )
      yapf --version
      clang-format --version
      exit 0
      ;;
    -h | --help )
      print_usage
      exit 0
      ;;
    * )
      print_usage
      exit 1
      ;;
  esac

  shift
done

# Validate no mutually exclusive options are set.
if [[ "${CHANGES_ONLY}" == "true" && "${STAGING_ONLY}" == "true" ]] || \
   [[ "${FORMAT_CPP}" == "false" && "${FORMAT_PYTHON}" == "false" ]]; then
  print_usage
  exit 1
fi

# Verify the YAPF version.
if [[ "${FORMAT_PYTHON}" == "true" ]]; then
  EXPECTED_YAPF_VERSION="0.20.2"
  YAPF_VERSION=$(yapf --version | cut -d' ' -f2)
  if [[ "${YAPF_VERSION}" != "${EXPECTED_YAPF_VERSION}" ]]; then
    >&2 echo "YAPF version mismatch"
    >&2 echo "got: ${YAPF_VERSION}, but expected: ${EXPECTED_YAPF_VERSION}"
    >&2 echo "please install the correct version and try again"
    exit 3
  fi
fi

# Verify the clang-format version.
if [[ "${FORMAT_CPP}" == "true" ]]; then
  EXPECTED_CF_VERSION="6.0.0"
  CF_VERSION=$(clang-format --version | cut -d' ' -f3 | cut -d'-' -f1)
  if [[ "${CF_VERSION}" != "${EXPECTED_CF_VERSION}" ]]; then
    >&2 echo "clang-format version mismatch"
    >&2 echo "got: ${CF_VERSION}, but expected: ${EXPECTED_CF_VERSION}"
    >&2 echo "please install the correct version and try again"
    exit 4
  fi
fi

# Verify a catkin workspace is available.
if [[ ! -d "${DIR}/catkin_ws" ]]; then
  >&2 echo "could not find catkin_ws in ${DIR}"
  exit 5
fi

# Get (A)dded, (C)opied, (M)odified, (R)enamed, or changed (T) files
if [[ "${STAGING_ONLY}" == "true" ]]; then
  CHANGED_FILES="$(git diff --name-only --diff-filter=ACMRT --cached HEAD)"
elif [[ "${CHANGES_ONLY}" == "true" ]]; then
  CHANGED_FILES="$(git diff --name-only --diff-filter=ACMRT ${REVISION})"
fi

# Get all submodule paths.
SUBMODULE_PATHS="$(grep "path" "${DIR}/.gitmodules" | sed 's/.*= //')"
FIND_EXCLUDES="$(printf "! -path '${DIR}/%s/*' " ${SUBMODULE_PATHS})"
GREP_EXCLUDES="$(printf "${DIR}/%s," ${SUBMODULE_PATHS})"

#
# YAPF
#

if [[ "${DRY_RUN}" == "true" ]]; then
  YAPF_ARGS="--diff"
else
  YAPF_ARGS="--in-place"
fi

if [[ "${CHANGES_ONLY}" == "true" || "${STAGING_ONLY}" == "true" ]]; then
  if [[ -z "${CHANGED_FILES}" ]]; then
    PY_FILES=""
    SHEBANG_FILES=""
  else
    PY_FILES="$(echo "${CHANGED_FILES}" | grep '\.py$')"
    SHEBANG_FILES="$(grep -l '^#!/.*python' "${CHANGED_FILES}")"
  fi
elif [[ -z "${PACKAGE}" ]]; then
  PY_FILES="$(eval find ${DIR}/catkin_ws/src -iname '*.py' ${FIND_EXCLUDES})"
  SHEBANG_FILES="$(
    eval find ${DIR}/catkin_ws/src -type f |  # Ignore symlinks.
      grep -l '^#!/.*python' --exclude-dir=\{${GREP_EXCLUDES}\}
  )"
else
  # Don't exclude any submodules if a package was specified.
  PY_FILES="$(find ${DIR}/catkin_ws/src/${PACKAGE} -iname '*.py')"
  SHEBANG_FILES="$(
    find ${DIR}/catkin_ws/src/${PACKAGE} -type f |  # Ignore symlinks.
      grep -l '^#!/.*python'
   )"
fi

YAPF_FILES="$(
  echo ${PY_FILES} ${SHEBANG_FILES} |
    sed '/^[[:blank:]]*$/d' |
    uniq |
    tr '\n' ' '
 )"

if [[ "${FORMAT_PYTHON}" == "true" ]]; then
  if [[ -n "${YAPF_FILES}" ]]; then
    if [[ "${VERBOSE}" == "true" ]]; then
      COUNT="$(
        echo ${YAPF_FILES} |
          tr ' ' '\n' |
          wc -l |
          sed -e 's/^[[:space:]]*//'
      )"
      echo "running yapf on ${COUNT} file(s):"
      echo ${YAPF_FILES} | tr ' ' '\n'
    fi
    eval yapf --parallel --recursive ${YAPF_ARGS} ${YAPF_FILES}
  elif [[ "${VERBOSE}" == "true" ]]; then
    echo "found no python sources: skipping..."
  fi
fi

#
# Clang-Format
#

if [[ ${CHANGES_ONLY} == "true" ]]; then
  # Get all (A)dded, (C)opied, (M)odified, (R)enamed, or changed (T) files
  # relative to the $BRANCH branch.
  CLANG_FORMAT_FILES="$(
    echo "${CHANGED_FILES}" |
      grep \
        -e '\.h$' \
        -e '\.c$' \
        -e '\.cpp$' \
        -e '\.hpp$' \
        -e '\.ino$' \
  )"
elif [[ -z "${PACKAGE}" ]]; then
  CLANG_FORMAT_FILES="$(
    eval "find ${DIR}/catkin_ws/src \\( \
        -iname '*.h' -o \
        -iname '*.c' -o \
        -iname '*.cpp' -o \
        -iname '*.hpp' -o \
        -iname '*.ino' \
      \\) -and ${FIND_EXCLUDES}"
  )"
else
  # Don't exclude any submodules if a package was specified.
  CLANG_FORMAT_FILES="$(
    eval find "${DIR}/catkin_ws/src/${PACKAGE}" \
      -iname '*.h' -o \
      -iname '*.c' -o \
      -iname '*.cpp' -o \
      -iname '*.hpp' -o \
      -iname '*.ino'
  )"
fi

if [[ "${FORMAT_CPP}" == "true" ]]; then
  if [[ -n "${CLANG_FORMAT_FILES}" ]]; then
    if [[ "${VERBOSE}" == "true" ]]; then
      COUNT="$(
        echo ${CLANG_FORMAT_FILES} |
          tr ' ' '\n' |
          wc -l |
          sed -e 's/^[[:space:]]*//'
      )"
      echo "running clang-format on ${COUNT} file(s):"
      echo "${CLANG_FORMAT_FILES}"
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
      for f in ${CLANG_FORMAT_FILES}; do
        diff ${f} <(clang-format ${f})
      done
    else
      echo "${CLANG_FORMAT_FILES}" | xargs clang-format -i
    fi
  elif [[ "${VERBOSE}" == "true" ]]; then
    echo "found no C++ sources: skipping..."
  fi
fi

exit 0
