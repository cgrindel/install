#!/usr/bin/env bash
#
# Bootstrap a Glydways Coder workspace.
#
# Clones cgrindel/dev-machine under ~/code/cgrindel and hands off to its
# gw_setup script. Designed to be invoked via:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/cgrindel/install/HEAD/gw_install.sh)"
#
# Assumes the workspace is provisioned with an SSH key that has access
# to cgrindel's private GitHub repos (standard on Glydways Coder).

set -o errexit -o nounset -o pipefail

# Ensure zsh is installed. Coder workspace images are Ubuntu-based and
# ship with bash only, so a fresh workspace needs zsh pulled in.
if ! command -v zsh >/dev/null 2>&1; then
  echo >&2 "zsh not found; installing via apt..."
  sudo apt-get update
  sudo apt-get install -y zsh
fi

# Make zsh the default login shell so it persists across reconnects.
# Use sudo because Coder workspace users often have no password set,
# which would otherwise cause chsh to prompt or fail.
ZSH_PATH="$(command -v zsh)"
CURRENT_SHELL="$(getent passwd "${USER}" | cut -d: -f7)"
if [[ ${CURRENT_SHELL} != "${ZSH_PATH}" ]]; then
  echo >&2 "Changing default shell for ${USER} to ${ZSH_PATH}..."
  sudo chsh -s "${ZSH_PATH}" "${USER}"
fi

REPO_DIR="${HOME}/code/cgrindel/dev-machine"
REPO_URL="git@github.com:cgrindel/dev-machine.git"
DEFAULT_BRANCH="main"

mkdir -p "$(dirname "${REPO_DIR}")"

# Pre-accept github.com's host key so the clone doesn't fail on a
# fresh workspace where ~/.ssh/known_hosts hasn't seen github.com yet.
# Plain ssh here will fail authentication (Coder's gitssh wrapper only
# kicks in under git), but the host-key handshake happens *before* auth,
# so the host key still lands in known_hosts. The "|| true" absorbs the
# expected non-zero exit from the failed auth attempt.
mkdir -p -m 700 "${HOME}/.ssh"
ssh -o StrictHostKeyChecking=accept-new -T git@github.com >/dev/null 2>&1 || true

# Track workspace state so the EXIT trap can restore it on success,
# failure, or interrupt. Flags are only flipped after the matching
# git operation succeeds, so a partial failure won't try to undo work
# that never happened.
ORIG_BRANCH=""
STASHED=0

cleanup() {
  local rc=$?
  trap - EXIT
  if ! cd "${REPO_DIR}" 2>/dev/null; then
    return "${rc}"
  fi
  if [[ -n ${ORIG_BRANCH} ]]; then
    echo >&2 "Restoring branch ${ORIG_BRANCH}..."
    if ! git checkout "${ORIG_BRANCH}"; then
      echo >&2 "Warning: failed to checkout ${ORIG_BRANCH};" \
        "workspace left on ${DEFAULT_BRANCH}."
    fi
    ORIG_BRANCH=""
  fi
  if [[ ${STASHED} -eq 1 ]]; then
    echo >&2 "Restoring stashed changes..."
    if ! git stash pop; then
      echo >&2 "Warning: 'git stash pop' failed; your changes remain on" \
        "the stash. Inspect with 'git stash list' in ${REPO_DIR}."
    fi
    STASHED=0
  fi
  return "${rc}"
}

trap cleanup EXIT

if [[ -d "${REPO_DIR}/.git" ]]; then
  echo >&2 "dev-machine already present at ${REPO_DIR}; updating..."
  cd "${REPO_DIR}"
  # git symbolic-ref fails on detached HEAD; in that case we skip the
  # branch dance and just pull whatever is checked out.
  if CURRENT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null)"; then
    if [[ ${CURRENT_BRANCH} != "${DEFAULT_BRANCH}" ]]; then
      if [[ -n "$(git status --porcelain)" ]]; then
        echo >&2 "Stashing local changes on ${CURRENT_BRANCH}..."
        git stash push -u -m \
          "gw_install auto-stash $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        STASHED=1
      fi
      echo >&2 "Switching from ${CURRENT_BRANCH} to ${DEFAULT_BRANCH}..."
      ORIG_BRANCH="${CURRENT_BRANCH}"
      git checkout "${DEFAULT_BRANCH}"
    fi
  else
    echo >&2 "Warning: detached HEAD in ${REPO_DIR};" \
      "skipping branch switch."
  fi
  git pull --rebase
else
  echo >&2 "Cloning dev-machine to ${REPO_DIR}..."
  # Do not override GIT_SSH_COMMAND: Coder workspaces set it to their
  # own auth helper (e.g. "coder gitssh --"), which is what makes SSH
  # to GitHub work here. Replacing it with plain ssh breaks auth.
  git clone "${REPO_URL}" "${REPO_DIR}"
  cd "${REPO_DIR}"
fi

echo >&2 "Running gw_setup..."
# Not exec'd: the EXIT trap needs to fire after gw_setup to restore
# the original branch and pop the auto-stash. errexit propagates a
# non-zero exit from gw_setup as the script's exit status.
"${REPO_DIR}/gw_setup"
