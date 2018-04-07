# tools.sh

[job_icon]: https://dev.mcgillrobotics.com/buildStatus/icon?job=tools.sh/master
[job_url]: https://dev.mcgillrobotics.com/job/tools.sh/job/master
[![job_icon]][job_url]

This repository tracks a set of shell scripts used at McGill Robotics.

## Table of Contents

   * [Setup](#setup)
   * [Usage](#usage)
      * [`format.sh`](#formatsh)
      * [`lint.sh`](#lintsh)
      * [`sync.sh`](#syncsh)
      * [`update_repo.sh`](#update_reposh)
   * [Linting](#linting)

## Setup

Clone this repository and add it to your `$PATH`.

## Usage

### `format.sh`

This script auto-formats all Python and C++ code in the current repository
with [`yapf`](https://github.com/google/yapf) and
[`clang-format`](https://clang.llvm.org/docs/ClangFormat.html). To use,
simply navigate to the `git` repository you want to format and run:

```bash
format.sh
```

More options are available under:

```bash
format.sh --help
```

**Note**: This script expects the repository to contain a `catkin_ws`
directory at the root.

### `lint.sh`

This script lints all of our `catkin` packages using
[`catkin_lint`](https://github.com/fkie/catkin_lint). It has the added
benefit of ignoring submodules and any errors that are specified in a
`.lintignore` file in the root of your repository. To use, simply navigate to
the `git` repository you want to format and run:

```bash
lint.sh
```

The `.lintignore` is a list of the errors you want to ignore, one per line. The
following is an example:

```
critical_var_append
order_violation
```

**Note**: This script expects the repository to contain a `catkin_ws`
directory at the root.

### `sync.sh`

This script allows one to easily sync this repository and its submodules with
any machine on a local network in the event an internet connection is
unavailable. The only constraint is that you must be able to SSH into the target
machine. To use, simply navigate to the `git` repository you want to sync and
follow the following instructions.

_For the following, the `$MACHINE` argument will reference the `user@host`
required to SSH into the machine. For example, if we could SSH into a machine
with `ssh root@example.com`, then the `$MACHINE` argument should be
`root@example.com`._

#### `init`

Initialize the bare repositories on the remote machine via SSH and add them as a
remote to our local repository and all of its submodules. This only needs to be
done once for each new machine and you can support an unlimited number of
machines with unique `$MACHINE` names.

```bash
sync.sh init $MACHINE
```

or

```bash
sync.sh init $MACHINE --root $ROOT
```

The `$ROOT` argument is an optional argument that defaults to `~/repos`.

This will do the following:

- SSH into the machine and create a folder in `$ROOT` for each
  repository/submodule in this repo.
- Run `git init --bare` for each of the above repositories.
- Run `git config --global --replace-all url."$ROOT".insteadOf 'git@github.com:'`.
  This means that every pull/push/fetch on that machine to a GitHub repository
  will now reference the locally bare repositories instead.
- Run `git config --global --replace-all url."git@github.com:".insteadOf 'https://github.com/'`.
  This allows for HTTPS repositories to get the same treatment as SSH
  repositories.

#### `push`

Push the repository to the machine's bare repositories.

```bash
sync.sh push $MACHINE
```

You can also add additional arguments to the underlying `git push` command with
`--`. For example, to force push, you can run:

```bash
sync.sh push $MACHINE -- -f
```

On the target machine, you can now simply clone the repo and all of its
submodules without internet access as it will automatically lookup the bare
repositories instead of GitHub. Pulling, fetching and pushing would also just
work as usual.

#### `pull` or `fetch`

Pull or fetch any changes made on the remote machine from their bare
repositories.

```bash
sync.sh pull $MACHINE
sync.sh fetch $MACHINE
```

Additional arguments can also be passed with `--` just like with `sync.sh push`
if needed.

#### `--help`

Additional command-line arguments are available and documented in:

```bash
sync.sh --help
```

### `update_repo.sh`

**Here be dragons!** Only use this script if you know what you're doing.

This script updates the current repository and all of its submodules to match
the latest remote revision. The motivation for this script is to minimize
potential human error when updating your repository (e.g. forgetting to update
submodules) and to simplify dealing with forks that are constantly rebased or
force pushed to. To use, just navigate to the `git` repository you want to
update and run:

```bash
update_repo.sh
```

## Linting

We use [`shellcheck`](https://shellcheck.net) to verify our shell scripts before
pushing our changes.
