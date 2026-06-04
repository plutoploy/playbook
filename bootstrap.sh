#!/bin/sh
# Bootstrap — detects OS, installs Ansible, then runs ansible-pull.
# One-liner usage:
#   curl -fsSL https://raw.githubusercontent.com/pratyay360/playbook/main/bootstrap.sh | sh

set -eu

REPO_URL="${ANSIBLE_REPO_URL:-https://github.com/plutoploy/playbook.git}"
BRANCH="${ANSIBLE_BRANCH:-main}"
PLAYBOOK="${ANSIBLE_PLAYBOOK:-site.yml}"
setup_backup() {
  curl https://raw.githubusercontent.com/pratyay360/playbook/main/backup.sh -o $HOME/.local/bin/backup.sh
  chmod +x $HOME/.local/bin/backup.sh 2>&1
  echo "Backup script installed to $HOME/.local/bin/backup.sh"
}


install_ansible() {
  if command -v ansible-pull >/dev/null 2>&1; then
    echo "==> ansible already installed, skipping."
    return
  fi

  echo "==> Detecting OS..."

  # Debian / Ubuntu
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y ansible

  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y epel-release
    sudo yum update -y
    sudo yum install -y ansible-core

  # Arch Linux
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm ansible

  # Alpine
  elif command -v apk >/dev/null 2>&1; then
    sudo apk add --no-cache ansible

  # FreeBSD
  elif command -v pkg >/dev/null 2>&1; then
    sudo pkg install -y py311-ansible

  # macOS (Homebrew)
  elif command -v brew >/dev/null 2>&1; then
    brew install ansible

  # Fallback: pipx
  elif command -v pipx >/dev/null 2>&1; then
    pipx install ansible-core

  # Last resort: pip
  elif command -v pip3 >/dev/null 2>&1; then
    pip3 install --user ansible-core

  else
    echo "ERROR: Could not detect a supported package manager. Install ansible manually." >&2
    exit 1
  fi
}

install_ansible

echo "==> Installing required Ansible collections..."
TMPDIR=$(mktemp -d)
git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${TMPDIR}/repo" 2>/dev/null
ansible-galaxy collection install -r "${TMPDIR}/repo/collections/requirements.yml"
rm -rf "${TMPDIR}"

echo "net.core.rmem_max=7340032\nnet.core.wmem_max=7340032" >> /etc/sysctl.d/69-service.conf

systemctl daemon-reload

echo "==> Running ansible-pull from ${REPO_URL} (branch: ${BRANCH})..."
ansible-pull \
  --url "${REPO_URL}" \
  --checkout "${BRANCH}" \
  --inventory "localhost," \
  --connection local \
  --limit localhost \
  "${PLAYBOOK}"
