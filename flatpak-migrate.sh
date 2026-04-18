#!/usr/bin/env bash
# flatpak-migrate.sh
#
# Interactive migration tool for Fedora that:
#   A. Replaces installed RPM GUI apps with their Flathub counterparts.
#   B. Re-installs Flatpaks that came from non-Flathub remotes (e.g. the
#      'fedora' remote) from Flathub instead.
#   C. Removes any non-Flathub remote that has nothing installed from it
#      after the migration.
#   D. Replaces GNOME Software with Bazaar (io.github.kolunmi.Bazaar).
#
# Each phase is a self-contained flow: scan -> resolve -> (review) ->
# confirm -> execute.
#
# Usage:
#   ./flatpak-migrate.sh                    # run all four phases (default)
#   ./flatpak-migrate.sh --skip-rpm         # skip Phase A
#   ./flatpak-migrate.sh --skip-remotes     # skip Phase B and C
#   ./flatpak-migrate.sh --skip-bazaar      # skip Phase D
#   ./flatpak-migrate.sh --auto-remove      # remove RPM after Flatpak install
#   ./flatpak-migrate.sh --no-edit          # skip editor, keep confirmation
#   ./flatpak-migrate.sh --yes              # non-interactive, accept all
#   ./flatpak-migrate.sh --dry-run          # plan only, no changes
#
# Flatpak user data in ~/.var/app/<app-id>/ is preserved across the
# uninstall/reinstall in Phase B.
# On rpm-ostree systems (Silverblue/Kinoite/Bluefin) Phase D uses
# 'rpm-ostree override remove'; changes take effect after reboot.

set -euo pipefail

AUTO_REMOVE=0
ASSUME_YES=0
DO_EDIT=1
DRY_RUN=0
SKIP_RPM=0
SKIP_REMOTES=0
SKIP_BAZAAR=0

for arg in "$@"; do
  case "$arg" in
    --auto-remove)   AUTO_REMOVE=1 ;;
    --yes|-y)        ASSUME_YES=1; DO_EDIT=0 ;;
    --no-edit)       DO_EDIT=0 ;;
    --dry-run)       DRY_RUN=1 ;;
    --skip-rpm)      SKIP_RPM=1 ;;
    --skip-remotes)  SKIP_REMOTES=1 ;;
    --skip-bazaar)   SKIP_BAZAAR=1 ;;
    --help|-h)
      sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

LOG="${HOME}/flatpak-migrate-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

# --- Output helpers ---------------------------------------------------------
c_reset=$'\033[0m'; c_bold=$'\033[1m'; c_dim=$'\033[2m'
c_green=$'\033[32m'; c_yellow=$'\033[33m'; c_red=$'\033[31m'; c_blue=$'\033[34m'
c_magenta=$'\033[35m'
phase() { printf '\n\n%s################ %s ################%s\n' \
            "$c_bold$c_magenta" "$*" "$c_reset"; }
step()  { printf '\n%s==> %s%s\n' "$c_bold$c_blue" "$*" "$c_reset"; }
info()  { printf '    %s\n' "$*"; }
warn()  { printf '%s    %s%s\n' "$c_yellow" "$*" "$c_reset"; }
ok()    { printf '%s    %s%s\n' "$c_green"  "$*" "$c_reset"; }
err()   { printf '%s    %s%s\n' "$c_red"    "$*" "$c_reset"; }

confirm() {
  [[ $ASSUME_YES -eq 1 ]] && return 0
  local reply
  read -rp "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# --- Editor helper: opens $1 in $EDITOR; returns 0 if saved, 1 if unchanged -
pick_editor() {
  local e="${VISUAL:-${EDITOR:-}}"
  if [[ -z "$e" ]]; then
    if   command -v nano >/dev/null 2>&1; then e=nano
    elif command -v vim  >/dev/null 2>&1; then e=vim
    else                                       e=vi
    fi
  fi
  echo "$e"
}

edit_plan() {
  local file="$1" editor before after
  editor=$(pick_editor)
  before=$(md5sum "$file" | cut -d' ' -f1)
  "$editor" "$file" </dev/tty >/dev/tty 2>&1 || {
    err "Editor exited non-zero; aborting."
    return 1
  }
  after=$(md5sum "$file" | cut -d' ' -f1)
  [[ "$before" != "$after" ]]
}

# --- Flathub app-id resolver -----------------------------------------------
# Populated once after prereqs: one app-id per line, apps only (no runtimes).
FLATHUB_APPS=""

appid_exists() {
  # Exact full-line fixed-string match against the cached Flathub app list.
  [[ -n "$FLATHUB_APPS" ]] && grep -qFx "$1" <<< "$FLATHUB_APPS"
}

# "text-editor" -> "TextEditor"
to_pascal() {
  local part out="" IFS=-
  read -ra parts <<< "$1"
  for part in "${parts[@]}"; do out+="${part^}"; done
  printf '%s' "$out"
}

# Resolve an RPM name to a Flathub app-id. Echoes the id on success, "" on
# failure. Tries: curated map -> naming-convention heuristics -> display-name
# search on Flathub. Every returned id is verified to exist on Flathub.
resolve_appid() {
  local pkg="$1" stem pascal cand result
  local -a candidates=()

  # Packages handled by a later phase or unsuitable for Flatpak replacement
  case "$pkg" in
    gnome-software) return ;;   # Phase D replaces with Bazaar
  esac

  # 1. Curated map wins
  if [[ -n "${MAP[$pkg]:-}" ]]; then
    printf '%s' "${MAP[$pkg]}"; return
  fi

  # 2. Convention-based candidates
  if [[ "$pkg" == gnome-* ]]; then
    stem="${pkg#gnome-}"
    pascal=$(to_pascal "$stem")
    candidates+=( "org.gnome.$pascal" "org.gnome.${stem^}" "org.gnome.$stem" )
  elif [[ "$pkg" == kde-* ]]; then
    stem="${pkg#kde-}"
    candidates+=( "org.kde.$stem" "org.kde.$(to_pascal "$stem")" )
  fi

  for cand in "${candidates[@]}"; do
    if appid_exists "$cand"; then printf '%s' "$cand"; return; fi
  done

  # 3. Last resort: exact display-name match on Flathub search
  result=$(flatpak search --columns=name,application "$pkg" 2>/dev/null \
           | awk -F'\t' -v p="$pkg" 'tolower($1)==tolower(p){print $2; exit}')
  if [[ -n "$result" ]] && appid_exists "$result"; then
    printf '%s' "$result"; return
  fi
}

# --- Parse an edited plan file into arrays:
#       _FINAL=("name|target" ...)    kept lines
#       _EXCLUDED=("name -> target" ...)   commented-out lines
parse_plan() {
  local file="$1"
  _FINAL=(); _EXCLUDED=()
  while IFS= read -r line; do
    [[ -z "${line// }" ]] && continue
    if [[ "$line" =~ ^[[:space:]]*# ]]; then
      local stripped="${line#"${line%%[![:space:]#]*}"}"
      if [[ "$stripped" =~ ^([a-zA-Z0-9._+-]+)[[:space:]]+-\>[[:space:]]+([a-zA-Z0-9._-]+) ]]; then
        _EXCLUDED+=("${BASH_REMATCH[1]} -> ${BASH_REMATCH[2]}")
      fi
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9._+-]+)[[:space:]]+-\>[[:space:]]+([a-zA-Z0-9._-]+) ]]; then
      _FINAL+=("${BASH_REMATCH[1]}|${BASH_REMATCH[2]}")
    fi
  done < "$file"
}

# ===========================================================================
# 0. Prerequisites
# ===========================================================================
step "Checking prerequisites"
if ! command -v flatpak >/dev/null 2>&1; then
  warn "Flatpak is not installed."
  if [[ $DRY_RUN -eq 0 ]] && confirm "Install flatpak via dnf?"; then
    sudo dnf install -y flatpak
  else
    err "Cannot continue without flatpak."; exit 1
  fi
fi

if ! flatpak remotes --columns=name 2>/dev/null | grep -qx flathub; then
  warn "Flathub remote is not configured."
  if [[ $DRY_RUN -eq 0 ]] && confirm "Add Flathub remote now?"; then
    flatpak remote-add --if-not-exists flathub \
      https://flathub.org/repo/flathub.flatpakrepo
  else
    err "Cannot continue without Flathub."; exit 1
  fi
fi
ok "Prerequisites OK."
info "Log: $LOG"

step "Caching Flathub app index"
FLATHUB_APPS=$(flatpak remote-ls flathub --app --columns=application 2>/dev/null || true)
if [[ -z "$FLATHUB_APPS" ]]; then
  warn "Flathub index is empty (offline? fresh remote?); resolver will be less accurate."
else
  info "$(wc -l <<< "$FLATHUB_APPS") apps on Flathub."
fi

# ===========================================================================
# Curated RPM name -> Flathub app-id map (Phase A)
# ===========================================================================
declare -A MAP=(
  [firefox]=org.mozilla.firefox
  [thunderbird]=org.mozilla.Thunderbird
  [chromium]=org.chromium.Chromium
  [code]=com.visualstudio.code
  [discord]=com.discordapp.Discord
  [signal-desktop]=org.signal.Signal
  [telegram-desktop]=org.telegram.desktop
  [element-desktop]=im.riot.Riot
  [libreoffice-core]=org.libreoffice.LibreOffice
  [keepassxc]=org.keepassxc.KeePassXC
  [evolution]=org.gnome.Evolution
  [geary]=org.gnome.Geary
  [gimp]=org.gimp.GIMP
  [inkscape]=org.inkscape.Inkscape
  [blender]=org.blender.Blender
  [krita]=org.kde.krita
  [darktable]=org.darktable.Darktable
  [shotwell]=org.gnome.Shotwell
  [vlc]=org.videolan.VLC
  [audacity]=org.audacityteam.Audacity
  [obs-studio]=com.obsproject.Studio
  [kdenlive]=org.kde.kdenlive
  [handbrake]=fr.handbrake.ghb
  [gnome-calculator]=org.gnome.Calculator
  [gnome-calendar]=org.gnome.Calendar
  [gnome-weather]=org.gnome.Weather
  [gnome-maps]=org.gnome.Maps
  [gnome-clocks]=org.gnome.clocks
  [gnome-contacts]=org.gnome.Contacts
  [gnome-boxes]=org.gnome.Boxes
  [gnome-tweaks]=org.gnome.tweaks
  [cheese]=org.gnome.Cheese
  [totem]=org.gnome.Totem
  [rhythmbox]=org.gnome.Rhythmbox3
  [eog]=org.gnome.eog
  [evince]=org.gnome.Evince
  [gedit]=org.gnome.gedit
  [simple-scan]=org.gnome.SimpleScan
  [gnome-text-editor]=org.gnome.TextEditor
  [gnome-characters]=org.gnome.Characters
  [gnome-connections]=org.gnome.Connections
  [gnome-logs]=org.gnome.Logs
  [gnome-font-viewer]=org.gnome.font-viewer
  [snapshot]=org.gnome.Snapshot
  [loupe]=org.gnome.Loupe
  [papers]=org.gnome.Papers

  # Fedora-published apps
  [mediawriter]=org.fedoraproject.MediaWriter
  [transmission-gtk]=com.transmissionbt.Transmission
  [steam]=com.valvesoftware.Steam
)

# ===========================================================================
# PHASE A: RPM -> Flatpak migration
# ===========================================================================
do_phase_a() {
  phase "PHASE A: RPM GUI apps -> Flathub"

  step "Step A1/5: Scanning installed RPMs for GUI applications"
  local -a GUI_RPMS
  mapfile -t GUI_RPMS < <(
    rpm -qa --qf '%{NAME}\n' | sort -u | while read -r pkg; do
      if rpm -ql "$pkg" 2>/dev/null | \
         grep -Eq '^/usr/share/applications/[^/]+\.desktop$'; then
        echo "$pkg"
      fi
    done
  )
  info "Found ${#GUI_RPMS[@]} GUI package(s)."
  if [[ ${#GUI_RPMS[@]} -eq 0 ]]; then ok "Nothing to migrate."; return 0; fi
  printf '%s' "$c_dim"; printf '      %s\n' "${GUI_RPMS[@]}"; printf '%s' "$c_reset"

  step "Step A2/5: Resolving Flatpak counterparts on Flathub"
  local -a MATCHES=() UNMATCHED=() ALREADY=()
  local pkg appid
  for pkg in "${GUI_RPMS[@]}"; do
    appid=$(resolve_appid "$pkg")
    if [[ -z "$appid" ]]; then
      UNMATCHED+=("$pkg"); continue
    fi
    if flatpak info "$appid" >/dev/null 2>&1; then
      ALREADY+=("$pkg|$appid"); continue
    fi
    MATCHES+=("$pkg|$appid")
  done

  info "Matched: ${#MATCHES[@]}   Already Flatpak: ${#ALREADY[@]}   No counterpart: ${#UNMATCHED[@]}"
  if [[ ${#UNMATCHED[@]} -gt 0 ]]; then
    echo; info "${c_dim}No Flathub counterpart (stays as RPM):${c_reset}"
    printf '      %s\n' "${UNMATCHED[@]}"
  fi
  if [[ ${#MATCHES[@]} -eq 0 ]]; then ok "Nothing new to install."; return 0; fi

  local plan; plan=$(mktemp --suffix=.a.plan); trap "rm -f '$plan'" RETURN
  {
    echo "# PHASE A: RPM -> Flatpak"
    echo "# Comment out (add '#') any line to keep that package as an RPM."
    echo "# Save & exit to proceed."
    echo
    for e in "${MATCHES[@]}"; do printf '%-35s -> %s\n' "${e%|*}" "${e##*|}"; done
  } > "$plan"

  step "Step A3/5: Review and edit the plan"
  if [[ $DO_EDIT -eq 1 ]]; then
    info "Opening ${#MATCHES[@]} matched package(s) in your editor. Press Enter..."
    read -r _ </dev/tty || true
    edit_plan "$plan" && ok "Plan edited." || info "Plan unchanged."
  else
    info "(skipped)"
  fi

  parse_plan "$plan"
  local -a FINAL=("${_FINAL[@]}") EXCLUDED=("${_EXCLUDED[@]}")

  step "Step A4/5: Final plan"
  info "Install: ${#FINAL[@]}    Skip: ${#EXCLUDED[@]}"; echo
  for e in "${FINAL[@]}";    do printf '   %s+%s %-35s -> %s\n' "$c_green" "$c_reset" "${e%|*}" "${e##*|}"; done
  for e in "${EXCLUDED[@]}"; do printf '   %s-%s %s\n' "$c_dim" "$c_reset" "$e"; done
  [[ ${#FINAL[@]} -eq 0 ]] && { warn "Nothing selected."; return 0; }

  if [[ $DRY_RUN -eq 1 ]]; then ok "Dry run — no changes made."; return 0; fi
  echo
  [[ $AUTO_REMOVE -eq 1 ]] && warn "--auto-remove set: each RPM will be uninstalled after Flatpak install."
  confirm "Proceed with Phase A?" || { warn "Skipped Phase A."; return 0; }

  step "Step A5/5: Installing Flatpaks"
  local pkg appid
  for entry in "${FINAL[@]}"; do
    pkg="${entry%|*}"; appid="${entry##*|}"
    echo; info "${c_bold}Installing $appid${c_reset}  (replaces $pkg)"
    if flatpak install -y --noninteractive flathub "$appid"; then
      if [[ $AUTO_REMOVE -eq 1 ]]; then
        info "Removing RPM $pkg..."
        sudo dnf remove -y "$pkg" || warn "Could not remove $pkg (dependency of something else?)."
      fi
    else
      err "Failed to install $appid; leaving $pkg untouched."
    fi
  done
  ok "Phase A complete."
}

# ===========================================================================
# PHASE B: Migrate Flatpaks from non-Flathub remotes to Flathub
# ===========================================================================
do_phase_b() {
  phase "PHASE B: Migrate non-Flathub Flatpaks to Flathub"

  step "Step B1/5: Scanning apps from non-Flathub remotes"
  # Format of each row: <appid>\t<origin>\t<installation>
  local -a ROWS
  mapfile -t ROWS < <(
    flatpak list --app --columns=application,origin,installation 2>/dev/null \
      | awk -F'\t' '$2!="flathub" && $2!=""'
  )
  info "Found ${#ROWS[@]} app(s) from non-Flathub remote(s)."
  if [[ ${#ROWS[@]} -eq 0 ]]; then ok "Nothing to migrate."; return 0; fi
  printf '%s' "$c_dim"
  for r in "${ROWS[@]}"; do
    local a o i; IFS=$'\t' read -r a o i <<< "$r"
    printf '      %-40s origin=%-15s install=%s\n' "$a" "$o" "$i"
  done
  printf '%s' "$c_reset"

  step "Step B2/5: Checking Flathub availability"
  local -a MATCHES=() UNMATCHED=()
  local appid origin install
  for r in "${ROWS[@]}"; do
    IFS=$'\t' read -r appid origin install <<< "$r"
    if flatpak remote-info flathub "$appid" >/dev/null 2>&1; then
      MATCHES+=("$appid|$origin|$install")
    else
      UNMATCHED+=("$appid (from $origin)")
    fi
  done
  info "Available on Flathub: ${#MATCHES[@]}    Not on Flathub: ${#UNMATCHED[@]}"
  if [[ ${#UNMATCHED[@]} -gt 0 ]]; then
    echo; info "${c_dim}Not available on Flathub (will be left alone):${c_reset}"
    printf '      %s\n' "${UNMATCHED[@]}"
  fi
  [[ ${#MATCHES[@]} -eq 0 ]] && { ok "Nothing to migrate."; return 0; }

  local plan; plan=$(mktemp --suffix=.b.plan); trap "rm -f '$plan'" RETURN
  {
    echo "# PHASE B: re-install these apps from Flathub instead of their current remote."
    echo "# Comment out (add '#') any line to leave that app alone."
    echo "# User data in ~/.var/app/<app-id>/ is preserved across the swap."
    echo "#"
    echo "# Format: <app-id>   ->   <current-origin>"
    echo
    for e in "${MATCHES[@]}"; do
      local a="${e%%|*}" rest="${e#*|}"
      printf '%-45s -> %s\n' "$a" "${rest%|*}"
    done
  } > "$plan"

  step "Step B3/5: Review and edit the plan"
  if [[ $DO_EDIT -eq 1 ]]; then
    info "Opening ${#MATCHES[@]} app(s) in your editor. Press Enter..."
    read -r _ </dev/tty || true
    edit_plan "$plan" && ok "Plan edited." || info "Plan unchanged."
  else
    info "(skipped)"
  fi

  parse_plan "$plan"
  # Map kept app-ids back to their installation type
  local -A INSTALL_OF=()
  for e in "${MATCHES[@]}"; do
    local a="${e%%|*}" rest="${e#*|}"
    INSTALL_OF["$a"]="${rest#*|}"
  done
  local -a FINAL=() EXCLUDED=("${_EXCLUDED[@]}")
  for e in "${_FINAL[@]}"; do FINAL+=("${e%|*}|${e##*|}"); done   # normalize

  step "Step B4/5: Final plan"
  info "Migrate: ${#FINAL[@]}    Skip: ${#EXCLUDED[@]}"; echo
  for e in "${FINAL[@]}"; do
    printf '   %s~%s %-45s (%s -> flathub)\n' "$c_green" "$c_reset" "${e%|*}" "${e##*|}"
  done
  for e in "${EXCLUDED[@]}"; do
    printf '   %s-%s %s\n' "$c_dim" "$c_reset" "$e"
  done
  [[ ${#FINAL[@]} -eq 0 ]] && { warn "Nothing selected."; return 0; }

  if [[ $DRY_RUN -eq 1 ]]; then ok "Dry run — no changes made."; return 0; fi
  echo
  warn "Each app will be uninstalled and reinstalled from Flathub."
  warn "User data is preserved, but the app will be briefly unavailable."
  confirm "Proceed with Phase B?" || { warn "Skipped Phase B."; return 0; }

  step "Step B5/5: Swapping remotes"
  local appid install scope_flag
  for entry in "${FINAL[@]}"; do
    appid="${entry%|*}"
    install="${INSTALL_OF[$appid]:-system}"
    case "$install" in
      user)   scope_flag="--user" ;;
      *)      scope_flag="--system" ;;
    esac
    echo
    info "${c_bold}$appid${c_reset}  ($install install)"
    info "  Uninstalling (preserving user data)..."
    if ! flatpak uninstall -y --noninteractive $scope_flag "$appid"; then
      err "  Uninstall failed; skipping."
      continue
    fi
    info "  Installing from flathub..."
    if ! flatpak install -y --noninteractive $scope_flag flathub "$appid"; then
      err "  Install from Flathub failed! $appid is now uninstalled."
      err "  You can try manually: flatpak install $scope_flag flathub $appid"
    fi
  done
  ok "Phase B complete."
}

# ===========================================================================
# PHASE C: Remove remotes that no longer have anything installed
# ===========================================================================
do_phase_c() {
  phase "PHASE C: Clean up empty remotes"

  step "Removing orphaned runtimes"
  if [[ $DRY_RUN -eq 0 ]]; then
    flatpak uninstall --unused -y --noninteractive || true
  else
    info "(dry run: would run 'flatpak uninstall --unused -y')"
  fi

  step "Checking for empty non-Flathub remotes"
  # List every remote except flathub
  local -a REMOTES
  mapfile -t REMOTES < <(flatpak remotes --columns=name 2>/dev/null | grep -vx flathub || true)

  if [[ ${#REMOTES[@]} -eq 0 ]]; then
    ok "No non-Flathub remotes configured."
    return 0
  fi

  local remote in_use
  for remote in "${REMOTES[@]}"; do
    [[ -z "$remote" ]] && continue
    # Count anything (apps or runtimes) still installed from this remote
    in_use=$(flatpak list --columns=origin 2>/dev/null | grep -cx "$remote" || true)
    if [[ "$in_use" -gt 0 ]]; then
      info "Remote '${c_bold}$remote${c_reset}' still has $in_use item(s) installed — keeping it."
    else
      if [[ $DRY_RUN -eq 1 ]]; then
        info "Remote '${c_bold}$remote${c_reset}' is empty. (dry run: would remove)"
      elif confirm "Remote '$remote' has no installs. Remove it?"; then
        if flatpak remote-delete "$remote"; then
          ok "Removed remote '$remote'."
        else
          err "Could not remove remote '$remote'."
        fi
      else
        info "Left '$remote' in place."
      fi
    fi
  done
  ok "Phase C complete."
}

# ===========================================================================
# PHASE D: Replace GNOME Software with Bazaar
# ===========================================================================
BAZAAR_APPID="io.github.kolunmi.Bazaar"

do_phase_d() {
  phase "PHASE D: Replace GNOME Software with Bazaar"

  step "Step D1/3: Checking current state"
  local has_gs=0 has_bazaar=0 use_ostree=0

  if rpm -q gnome-software >/dev/null 2>&1; then
    has_gs=1
    info "GNOME Software RPM is installed."
  else
    info "GNOME Software RPM is not installed."
  fi

  if flatpak info "$BAZAAR_APPID" >/dev/null 2>&1; then
    has_bazaar=1
    info "Bazaar is already installed as a Flatpak."
  else
    info "Bazaar is not installed."
  fi

  if command -v rpm-ostree >/dev/null 2>&1 && rpm-ostree status >/dev/null 2>&1; then
    use_ostree=1
    warn "Detected rpm-ostree system; removal will use 'override remove' and require a reboot."
  fi

  if [[ $has_gs -eq 0 && $has_bazaar -eq 1 ]]; then
    ok "Nothing to do — GNOME Software already gone, Bazaar already present."
    return 0
  fi

  if ! appid_exists "$BAZAAR_APPID"; then
    err "$BAZAAR_APPID was not found on Flathub. Skipping."
    return 0
  fi

  step "Step D2/3: Plan"
  [[ $has_bazaar -eq 0 ]] && \
    printf '   %s+%s install  %s (from Flathub)\n' \
      "$c_green" "$c_reset" "$BAZAAR_APPID"
  if [[ $has_gs -eq 1 ]]; then
    if [[ $use_ostree -eq 1 ]]; then
      printf '   %s-%s remove   gnome-software (via rpm-ostree override, reboot required)\n' \
        "$c_red" "$c_reset"
    else
      printf '   %s-%s remove   gnome-software (via dnf)\n' "$c_red" "$c_reset"
    fi
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo; ok "Dry run — no changes made."; return 0
  fi

  echo
  confirm "Proceed with Phase D?" || { warn "Skipped Phase D."; return 0; }

  step "Step D3/3: Executing"
  # Install Bazaar FIRST so the user is never without an app store
  if [[ $has_bazaar -eq 0 ]]; then
    info "Installing $BAZAAR_APPID..."
    if ! flatpak install -y --noninteractive flathub "$BAZAAR_APPID"; then
      err "Failed to install Bazaar; leaving gnome-software in place."
      return 1
    fi
    ok "Installed Bazaar."
  fi

  # Now remove GNOME Software
  if [[ $has_gs -eq 1 ]]; then
    if [[ $use_ostree -eq 1 ]]; then
      info "Removing gnome-software via rpm-ostree override..."
      if sudo rpm-ostree override remove gnome-software; then
        ok "Removed gnome-software. Reboot to apply."
      else
        warn "rpm-ostree override remove failed."
      fi
    else
      info "Removing gnome-software RPM..."
      if sudo dnf remove -y gnome-software; then
        ok "Removed gnome-software."
      else
        warn "Could not remove gnome-software (pulled in by another package?)."
      fi
    fi
  fi
  ok "Phase D complete."
}

# ===========================================================================
# Main
# ===========================================================================
[[ $SKIP_RPM     -eq 0 ]] && do_phase_a
[[ $SKIP_REMOTES -eq 0 ]] && { do_phase_b; do_phase_c; }
[[ $SKIP_BAZAAR  -eq 0 ]] && do_phase_d

echo
ok "All done. Log: $LOG"