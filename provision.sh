#!/usr/bin/env bash
#
# provision.sh — TeamAccess Setup
# Provisions a project group, three team accounts, password aging,
# scoped sudo, and a shared workspace with safe multi-user permissions.
#
# Tested on: RHEL 10
# Run as: root

set -euo pipefail

GROUP="projectteam"
USERS=("nkumar" "rpatel" "svarma")
ADMIN_USER="nkumar"              # sole sudo grantee
WORKDIR="/opt/teamshare"
SUDOERS_FILE="/etc/sudoers.d/teamaccess"
UMASK_FILE="/etc/profile.d/teamaccess-umask.sh"

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

echo ">> Ensuring group '${GROUP}' exists"
getent group "$GROUP" >/dev/null || groupadd "$GROUP"

echo ">> Creating/updating user accounts"
for u in "${USERS[@]}"; do
    if id "$u" &>/dev/null; then
        echo "   $u already exists — ensuring group membership and shell"
        usermod -aG "$GROUP" -s /bin/bash "$u"
    else
        useradd -m -d "/home/${u}" -s /bin/bash -G "$GROUP" "$u"
        echo "   created $u"
    fi
done

echo ">> Applying password aging policy (60d max, 7d warning, forced reset)"
for u in "${USERS[@]}"; do
    chage -M 60 -W 7 -d 0 "$u"
done

echo ">> Configuring sudo access (only ${ADMIN_USER})"
cat > "$SUDOERS_FILE" <<EOF
${ADMIN_USER} ALL=(ALL) ALL
EOF
chmod 0440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" || { echo "Bad sudoers syntax, aborting"; rm -f "$SUDOERS_FILE"; exit 1; }
# No entries written for the other two users — sudo denies by default.

echo ">> Building shared workspace at ${WORKDIR}"
mkdir -p "$WORKDIR"
chown root:"$GROUP" "$WORKDIR"
chmod 2775 "$WORKDIR"   # SGID so new files inherit the group
chmod +t "$WORKDIR"     # sticky bit so only owners can remove their own files

echo ">> Installing default umask for ${GROUP} members"
cat > "$UMASK_FILE" <<'EOF'
# Applied at login for members of projectteam.
if id -nG "$USER" 2>/dev/null | grep -qw "projectteam"; then
    umask 007
fi
EOF
chmod 644 "$UMASK_FILE"

echo ">> Done. Verify with: id, chage -l, sudo -l -U, ls -ld ${WORKDIR}"
