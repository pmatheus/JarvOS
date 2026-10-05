---
name: resolve-update-failure
description: Use when jarvos-update-resolve hands you a failed JarvOS update step to fix unattended, before the step is re-run and, failing that, the system is rolled back.
---

# Resolve an update failure

You are running unattended, inside a JarvOS update, with sudo. Nobody is
watching. A snapshot of the system was taken before the update began. After
you finish, the failed step runs again, and if it still fails the update rolls
the system back to that snapshot. Your job is to make the re-run succeed
without doing anything a human would have to undo.

## What already ran

The update runs, in order: `jarvos-update-git`, `jarvos-update-keyring`,
`jarvos-update-system-pkgs`, `jarvos-update-health`, the migrations and
post-update hooks, then `jarvos-update-aur-pkgs`. Each step already applied its
own rules before you were called:

- **git**: fetch, then fast-forward, rebase local commits, or (if upstream
  history was rewritten) reset to upstream with the old history kept on a
  `jarvos/backup/*` branch and local edits restored from a stash.
- **keyring**: `pacman-key --populate archlinux`, then another try.
- **system packages**: stale `db.lck` removed, `--ask=4` for package
  conflicts, `--overwrite` for exact unowned paths, keyring repopulation for
  bad signatures, and the corrupt download deleted.
- **health**: the gate that checks the package database, every installed
  kernel's `modules.dep`, `vmlinuz` and `initramfs` in `/boot`, and the NVIDIA
  DKMS module for each kernel.

So the failure in front of you is one those rules could not handle. Do not
just repeat them.

## Method

1. Read the transcript tail you were given and find the earliest real error.
   The last line is usually only an exit status.
2. Confirm the cause on the machine with read-only commands (`pacman -Qi`,
   `pacman -Qo`, `journalctl`, `git status`, `dkms status`, the Arch news at
   https://archlinux.org/news/ for a manual intervention).
3. Apply the smallest fix that addresses that cause. Typical fixes:
   - **Arch news manual intervention**: follow the published steps exactly.
   - **Owned file conflict after a package split or rename**: remove the
     obsolete package only if pacman's own replacement metadata or the Arch
     news says so.
   - **mkinitcpio or DKMS failed in the health gate**: read the hook output,
     fix the config or missing header, then `sudo mkinitcpio -P` or
     `sudo dkms autoinstall`.
   - **git rebase or stash conflict in the JarvOS checkout**: resolve it so
     both upstream changes and local edits survive. If they truly contradict,
     keep upstream in the tree and leave the local version in a stash or on a
     backup branch.
   - **AUR build failure**: missing PGP key (`gpg --recv-keys`), a stale build
     dir (`yay -Sc --aur`), a package that dropped from the AUR (leave it,
     report it).
4. Verify the fix yourself with the cheapest check that proves it, without
   running the jarvos-update step.

## Never

- run `jarvos-update` or any `jarvos-update-*` command (deadlock on the lock)
- touch `/home`, except the JarvOS checkout
- `pacman --overwrite` with a glob, or over a file another package owns
- `pacman -Rdd`, or removing an explicitly installed package pacman did not
  propose replacing
- delete, change or roll back snapper snapshots; reboot; power off
- `git push`, force anything, or discard uncommitted work
- disable signature checking, edit `SigLevel`, or add `IgnorePkg` to get past
  an error

If the safe fix needs a human decision, change nothing and say so.

## Verdict

Your final line is exactly one of:

- `JARVOS-RESOLVED`
- `JARVOS-UNRESOLVED <one sentence on why>`
