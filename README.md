# OnboardOps Provisioning Kit

A RHEL 10 mini-project simulating a real onboarding workflow for a new
engineering team: group/user provisioning, password aging policy, scoped
sudo access, and a shared collaborative directory with safe multi-user
permissions.

## Problem Statement

A new "devteam" is joining the organization. Three engineers need Linux
accounts on a shared server. The requirements from IT/security:

1. All three users belong to a common `devteam` group, each with a proper
   home directory and Bash login shell.
2. Passwords must expire every 60 days, with a 7-day warning, and every
   account must be forced to set a new password on first login.
3. Only **one** of the three users should have full administrative (sudo)
   rights — the other two must have none.
4. The team needs a shared folder where anyone in `devteam` can drop files,
   but **no one should be able to delete or overwrite a teammate's file**
   except its owner.
5. Files created in the shared folder should default to group-writable
   permissions, without being world-accessible.

## Technical Approach

| Requirement | Tool / Mechanism | Why |
|---|---|---|
| Group + users | `groupadd`, `useradd -m -d -s -G` | Native RHEL user management, no external tooling |
| Password aging | `chage -M -W -d 0` | `-d 0` resets the last-change date to the epoch, which forces a password reset at next login without needing `passwd -e` |
| Sudo scoping | `/etc/sudoers.d/<user>` drop-in + `visudo -cf` | Drop-in files keep `/etc/sudoers` untouched and are easy to audit/remove per user; `visudo -cf` validates syntax before it's trusted |
| Shared folder isolation | SGID (`chmod 2770`) + sticky bit (`chmod +t`) | SGID makes every new file inherit the `devteam` group automatically; sticky bit restricts deletion to the file owner and root, solving the "shared folder problem" where group-write alone would let anyone delete anyone's files |
| Default file permissions | `umask 007` via `/etc/profile.d/devteam-umask.sh` | Applied only to `devteam` members at shell login, so new files default to `rw-rw----` and directories to `rwxrwx---` — group-writable, closed to others |

All steps use only standard RH124/RH134 syllabus tools: `useradd`,
`groupadd`, `usermod`, `chage`, `visudo`, `chmod`, `chgrp`, `umask`. No
third-party packages required.

## Repository Structure

```
onboardops-provisioning-kit/
├── provision.sh          # Full automated setup script
├── README.md              # This file
├── commands.txt            # Command log, including failed attempts
├── verification.txt        # Verification command output
├── demo_video_script.md    # Script for a walkthrough demo video
└── screenshots/
    ├── 01-users-created.png
    ├── 02-chage-policy.png
    ├── 03-sudo-access.png
    ├── 04-shared-permissions.png
    ├── 05-sgid-inheritance.png
    └── 06-sticky-bit-denial.png
```

## How to Run

```bash
sudo bash provision.sh
```

## Verify it

See `commands.txt` for the full development log and `verification.txt`
for captured output of `id`, `chage -l`, `sudo -l -U`, and `ls -ld`.

## Screenshots

- `screenshots/01-users-created.png` — id output for all three users
- `screenshots/02-chage-policy.png` — chage -l output showing the policy
- `screenshots/03-sudo-access.png` — sudo -l -U for all three users
- `screenshots/04-shared-permissions.png` — ls -ld /shared/project
- `screenshots/05-sgid-inheritance.png` — file created by second user showing devteam group
- `screenshots/06-sticky-bit-denial.png` — non-owner delete attempt denied
