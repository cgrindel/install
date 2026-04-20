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

REPO_DIR="${HOME}/code/cgrindel/dev-machine"

mkdir -p "$(dirname "${REPO_DIR}")"

if [[ -d "${REPO_DIR}/.git" ]]; then
  echo >&2 "dev-machine already present at ${REPO_DIR}; pulling latest..."
  (cd "${REPO_DIR}" && git pull --ff-only)
else
  echo >&2 "Cloning dev-machine to ${REPO_DIR}..."
  GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" \
    git clone git@github.com:cgrindel/dev-machine.git "${REPO_DIR}"
fi

echo >&2 "Running gw_setup..."
exec "${REPO_DIR}/gw_setup"
