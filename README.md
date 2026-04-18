# flatpak-migrate

A single bash script that migrates a Fedora install toward a **Flathub-first** application setup. It does three things, each as an interactive, reviewable phase:

1. **Phase A** — Replaces installed RPM GUI applications with their Flathub counterparts.
2. **Phase B** — Re-installs Flatpaks that came from non-Flathub remotes (typically the `fedora` remote) from Flathub instead.
3. **Phase C** — Removes any non-Flathub remote that has nothing installed from it after the migration.

Each phase is a five-step flow: **scan → resolve → review/edit plan → confirm → execute**. Nothing is changed until you explicitly confirm, and the default flow opens each plan in your `$EDITOR` so you can comment out anything you don't want touched.

---

## Requirements

- Fedora (Workstation, Silverblue, Kinoite — anything with `rpm` and `dnf`/`rpm-ostree`)
- `bash` 4+
- `flatpak` (the script will offer to install it via `dnf` if missing)
- The Flathub remote (the script will offer to add it if missing)

> **Note on Silverblue/Kinoite:** Phase A's `sudo dnf remove` step will not work on immutable variants — you'd need `rpm-ostree override remove` instead. Phases B and C work unchanged. Run with `--skip-rpm` on those systems, or leave Phase A alone (don't pass `--auto-remove`) and handle RPM overrides manually.

---

## Installation

```sh
curl -LO https://example.com/flatpak-migrate.sh   # or copy the file over
chmod +x flatpak-migrate.sh
```

No other setup. The script is self-contained.

---

## Quick start

```sh
# See what would happen, change nothing
./flatpak-migrate.sh --dry-run

# Default interactive run: prompts + editor for each phase
./flatpak-migrate.sh

# Also uninstall the RPM versions after their Flatpaks install cleanly
./flatpak-migrate.sh --auto-remove

# Only swap Flatpak remotes; don't touch RPMs
./flatpak-migrate.sh --skip-rpm

# Only migrate RPMs; leave existing Flatpaks alone
./flatpak-migrate.sh --skip-remotes

# Fully non-interactive (use with care)
./flatpak-migrate.sh --yes --auto-remove
```

Every run writes a timestamped log to `$HOME/flatpak-migrate-YYYYMMDD-HHMMSS.log`.

---

## Flags

| Flag             | Effect                                                                     |
| ---------------- | -------------------------------------------------------------------------- |
| `--dry-run`      | Walk the full flow but make no changes. Can be combined with any other flag. |
| `--yes`, `-y`    | Don't prompt for anything. Implies `--no-edit`. Accepts every default.     |
| `--no-edit`      | Skip the `$EDITOR` step in each phase, but still ask for final confirmation. |
| `--auto-remove`  | After each Flatpak in Phase A installs cleanly, `dnf remove` its RPM.      |
| `--skip-rpm`     | Skip Phase A entirely.                                                     |
| `--skip-remotes` | Skip Phases B and C entirely.                                              |
| `--help`, `-h`   | Print the embedded header and exit.                                        |

---

## How each phase works

### Phase A — RPM GUI apps → Flathub

**Scan.** Walks every installed RPM (`rpm -qa`) and keeps only those that ship a `.desktop` file under `/usr/share/applications/`. This is how the script restricts itself to user-facing GUI apps — kernel modules, shared libraries, CLI tools, fonts, and drivers are never touched.

**Resolve.** For each GUI package it looks up a Flathub app-id via:

1. A built-in **curated map** (firefox → `org.mozilla.firefox`, `libreoffice-core` → `org.libreoffice.LibreOffice`, etc.), which handles the cases where RPM names and Flatpak app-ids differ meaningfully.
2. A fallback **Flathub name search** (`flatpak search`) for anything not in the map, accepting only exact (case-insensitive) name matches.

Every proposed match is verified with `flatpak remote-info flathub <app-id>` before being shown to you, so false positives from the name search don't make it into the plan.

**Review.** The plan opens in `$EDITOR` (or `$VISUAL`, falling back to `nano` → `vim` → `vi`). Comment out any line with `#` to keep that package as an RPM. Save and exit to continue, or leave the file empty to bail.

**Execute.** Each remaining entry is installed from Flathub. If `--auto-remove` is set, the corresponding RPM is removed afterwards with `sudo dnf remove`. Removal may fail if the package is pulled in as part of a dnf group (this is common with e.g. `firefox` on a fresh Workstation) — the script reports this clearly and moves on.

### Phase B — Non-Flathub Flatpaks → Flathub

**Scan.** Lists every installed Flatpak app whose origin is not `flathub` via `flatpak list --app --columns=application,origin,installation`. This typically catches things installed from Fedora's own Flatpak remote.

**Resolve.** For each app-id, checks whether Flathub offers a build.

**Review.** Same editor-based plan as Phase A.

**Execute.** For each selected app the script runs, in order:

```
flatpak uninstall -y --noninteractive <--user|--system> <app-id>
flatpak install   -y --noninteractive <--user|--system> flathub <app-id>
```

The original installation scope (`--user` vs `--system`) is preserved. **User data in `~/.var/app/<app-id>/` is not touched by `flatpak uninstall`**, so the Flathub reinstall picks up the same profile, config, and data. There is a brief window (usually seconds) between uninstall and install where the app is unavailable; if the install step fails, the script surfaces the error loudly so you know the app is currently gone.

### Phase C — Cleanup

**Orphan runtimes.** After Phase B, runtimes that only existed to support the old apps become unreferenced. The script runs `flatpak uninstall --unused -y` to clear them.

**Remote deletion.** For each remote that isn't `flathub`, counts how many installed apps/runtimes still reference it (`flatpak list --columns=origin | grep -cx <remote>`). If the count is zero, asks to run `flatpak remote-delete <remote>`. If the count is nonzero, the remote is left alone and the script tells you what's still using it.

---

## The plan-editor step

During each phase's review step the script writes a plain-text plan like this to a temp file and opens it in your editor:

```
# PHASE A: RPM -> Flatpak
# Comment out (add '#') any line to keep that package as an RPM.
# Save & exit to proceed.

firefox                             -> org.mozilla.firefox
libreoffice-core                    -> org.libreoffice.LibreOffice
# gimp                              -> org.gimp.GIMP       <- excluded
vlc                                 -> org.videolan.VLC
```

- To **skip** a line, prefix it with `#`.
- To **cancel the phase**, delete every non-comment line (or exit without saving — the script will also treat a non-zero editor exit as abort).
- Extra whitespace, tab-vs-space, and trailing comments are tolerated.

Use `--no-edit` if you want the script to just prompt-and-go with no editor step; use `--yes` to skip both editor and confirmation for automation.

---

## Extending the RPM → Flatpak map

The built-in `MAP` associative array near the top of the script covers ~40 common apps. To teach it about more, add entries in the form:

```bash
declare -A MAP=(
  ...
  [rpm-package-name]=io.github.example.AppId
  [another-rpm]=com.example.Another
)
```

Find the right app-id on [flathub.org](https://flathub.org/) — it appears in the URL (`flathub.org/apps/<app-id>`) and in `flatpak remote-info flathub <app-id>`. Anything you don't add to the map will still be found automatically if the RPM name happens to exactly match the Flathub app's display name.

---

## Examples

### Inspect what a fresh Workstation install would change

```sh
./flatpak-migrate.sh --dry-run
```

Reads-only, but walks the entire flow and prints the full plan for all three phases.

### Migrate everything, keep RPMs as backup

```sh
./flatpak-migrate.sh
```

Default. Installs Flathub versions alongside the RPMs, swaps Fedora-remote Flatpaks to Flathub, and cleans up empty remotes. The end of the run prints a ready-to-paste `sudo dnf remove …` line for the RPMs you can uninstall later once you're happy with the Flatpak versions.

### Commit fully to Flathub on first run

```sh
./flatpak-migrate.sh --auto-remove
```

Same as above but removes each RPM immediately after its Flatpak installs cleanly.

### Only fix the Flatpak-remotes side

```sh
./flatpak-migrate.sh --skip-rpm
```

Useful if you've already moved away from RPM GUI apps manually and just want to consolidate on Flathub.

---

## Troubleshooting

**"Could not remove `<package>` (likely pulled in by another package or group)."**
On Fedora Workstation, default apps like `firefox` are part of the `workstation-product` group. `dnf remove firefox` succeeds only if you also remove the group, which usually isn't what you want. Solutions: ignore the warning (the Flatpak is installed and takes precedence via the desktop file), or use `dnf remove --noautoremove <package>` and optionally drop the group with `sudo dnf group remove workstation-product`.

**"Failed to install `<app-id>`."**
Most often a transient Flathub fetch error. Re-run the script; already-installed Flatpaks are skipped automatically. In Phase B specifically, a failure means the app is currently uninstalled — re-run the install manually with `flatpak install flathub <app-id>`.

**"Remote '`<name>`' still has N item(s) installed — keeping it."**
Something on that remote isn't available on Flathub (or you kept it during Phase B). Either accept this and leave the remote, or remove the stragglers manually with `flatpak uninstall <app-id>` and re-run Phase C via `./flatpak-migrate.sh --skip-rpm`.

**The app-id lookup missed something obvious.**
The fallback search only accepts exact name matches. Add the package to the `MAP` block explicitly — see the section above.

---

## Safety notes

- Only packages that ship a `.desktop` file in `/usr/share/applications/` are considered in Phase A. System libraries, CLI tools, and kernel components are never candidates.
- No RPM is removed unless you pass `--auto-remove`, and even then only after its Flatpak has installed successfully.
- No RPM is removed if `dnf` reports a problem — the script does not pass any override flags.
- Phase B preserves `~/.var/app/<app-id>/`, where Flatpak stores per-app user data.
- Every run logs every action to a timestamped file in `$HOME`, including the commands executed, for post-hoc auditing.
- `--dry-run` is safe to combine with every other flag and performs no writes.
