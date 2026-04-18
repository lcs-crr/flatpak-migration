
==> Checking prerequisites
    Prerequisites OK.
    Log: /home/test/flatpak-migrate-20260418-122336.log

==> Caching Flathub app index
    3322 apps on Flathub.


################ PHASE A: RPM GUI apps -> Flathub ################

==> Step A1/5: Scanning installed RPMs for GUI applications
    Found 57 GUI package(s).
      abrt-gui
      anaconda-live
      anaconda-webui
      evolution-data-server
      firefox
      gcr3
      geoclue2
      gnome-abrt
      gnome-bluetooth
      gnome-browser-connector
      gnome-calendar
      gnome-characters
      gnome-color-manager
      gnome-connections
      gnome-contacts
      gnome-control-center
      gnome-disk-utility
      gnome-font-viewer
      gnome-initial-setup
      gnome-logs
      gnome-maps
      gnome-online-accounts
      gnome-remote-desktop
      gnome-shell
      gnome-software
      gnome-text-editor
      gnome-tour
      gnome-user-share
      gnome-weather
      ibus
      ibus-anthy
      ibus-chewing
      ibus-hangul
      ibus-libpinyin
      ibus-m17n
      ibus-setup
      ibus-typing-booster
      libreoffice-calc
      libreoffice-core
      libreoffice-impress
      libreoffice-writer
      libreoffice-xsltfilter
      loupe
      malcontent-control
      mediawriter
      nautilus
      ptyxis
      qemu-common
      rhythmbox
      rygel
      snapshot
      tecla
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      xdg-user-dirs-gtk
      xorg-x11-server-Xwayland
      yelp

==> Step A2/5: Resolving Flatpak counterparts on Flathub
    Matched: 9   Already Flatpak: 7   No counterpart: 41

    No Flathub counterpart (stays as RPM):
      abrt-gui
      anaconda-live
      anaconda-webui
      evolution-data-server
      gcr3
      geoclue2
      gnome-abrt
      gnome-bluetooth
      gnome-browser-connector
      gnome-color-manager
      gnome-control-center
      gnome-disk-utility
      gnome-initial-setup
      gnome-online-accounts
      gnome-remote-desktop
      gnome-shell
      gnome-software
      gnome-tour
      gnome-user-share
      ibus
      ibus-anthy
      ibus-chewing
      ibus-hangul
      ibus-libpinyin
      ibus-m17n
      ibus-setup
      ibus-typing-booster
      libreoffice-calc
      libreoffice-impress
      libreoffice-writer
      libreoffice-xsltfilter
      malcontent-control
      nautilus
      qemu-common
      rygel
      tecla
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      xdg-user-dirs-gtk
      xorg-x11-server-Xwayland
      yelp

==> Step A3/5: Review and edit the plan
    Opening 9 matched package(s) in your editor. Press Enter...

    Plan unchanged.

==> Step A4/5: Final plan
    Install: 9    Skip: 0

   + gnome-characters                    -> org.gnome.Characters
   + gnome-connections                   -> org.gnome.Connections
   + gnome-font-viewer                   -> org.gnome.font-viewer
   + gnome-logs                          -> org.gnome.Logs
   + gnome-text-editor                   -> org.gnome.TextEditor
   + loupe                               -> org.gnome.Loupe
   + mediawriter                         -> org.fedoraproject.MediaWriter
   + rhythmbox                           -> org.gnome.Rhythmbox3
   + snapshot                            -> org.gnome.Snapshot

    --auto-remove set: each RPM will be uninstalled after Flatpak install.
Proceed with Phase A? [y/N] y

==> Step A5/5: Installing Flatpaks

    Installing org.gnome.Characters  (replaces gnome-characters)
Installing runtime/org.gnome.Characters.Locale/x86_64/stable
Installing app/org.gnome.Characters/x86_64/stable
    Removing RPM gnome-characters...

We trust you have received the usual lecture from the local System
Administrator. It usually boils down to these three things:

    #1) Respect the privacy of others.
    #2) Think before you type.
    #3) With great power comes great responsibility.

For security reasons, the password you type will not be visible.

[sudo] password for test: 
Package           Arch   Version     Repository                            Size
Removing:
 gnome-characters x86_64 48.0-1.fc42 624cbc92582d4ecfae4c58749abde4f8   2.8 MiB

Transaction Summary:
 Removing:           1 package

After this operation, 3 MiB will be freed (install 0 B, remove 3 MiB).
Running transaction
[1/2] Prepare transaction               100% |  12.0   B/s |   1.0   B |  00m00s
[2/2] Removing gnome-characters-0:48.0- 100% | 170.0   B/s |  95.0   B |  00m01s
Complete!

    Installing org.gnome.Connections  (replaces gnome-connections)
Installing runtime/org.gnome.Connections.Locale/x86_64/stable
Installing app/org.gnome.Connections/x86_64/stable
    Removing RPM gnome-connections...
Package            Arch   Version      Repository                            Size
Removing:
 gnome-connections x86_64 48.0-1.fc42  624cbc92582d4ecfae4c58749abde4f8   1.1 MiB
Removing unused dependencies:
 gtk-vnc2          x86_64 1.5.0-3.fc42 <unknown>                        228.0 KiB
 gvnc              x86_64 1.5.0-3.fc42 <unknown>                        242.7 KiB
 gvncpulse         x86_64 1.5.0-3.fc42 <unknown>                         45.8 KiB

Transaction Summary:
 Removing:           4 packages

After this operation, 2 MiB will be freed (install 0 B, remove 2 MiB).
Running transaction
[1/5] Prepare transaction               100% |  44.0   B/s |   4.0   B |  00m00s
[2/5] Removing gnome-connections-0:48.0 100% |   3.4 KiB/s | 204.0   B |  00m00s
[3/5] Removing gtk-vnc2-0:1.5.0-3.fc42. 100% |   1.0 KiB/s |   8.0   B |  00m00s
[4/5] Removing gvncpulse-0:1.5.0-3.fc42 100% |   5.4 KiB/s |  61.0   B |  00m00s
[5/5] Removing gvnc-0:1.5.0-3.fc42.x86_ 100% |  11.0   B/s |  63.0   B |  00m06s
Complete!

    Installing org.gnome.font-viewer  (replaces gnome-font-viewer)
Installing runtime/org.gnome.font_viewer.Locale/x86_64/stable
Installing app/org.gnome.font-viewer/x86_64/stable
    Removing RPM gnome-font-viewer...
Package            Arch   Version     Repository                            Size
Removing:
 gnome-font-viewer x86_64 48.0-1.fc42 624cbc92582d4ecfae4c58749abde4f8   1.2 MiB

Transaction Summary:
 Removing:           1 package

After this operation, 1 MiB will be freed (install 0 B, remove 1 MiB).
Running transaction
[1/2] Prepare transaction               100% |  11.0   B/s |   1.0   B |  00m00s
[2/2] Removing gnome-font-viewer-0:48.0 100% | 473.0   B/s | 118.0   B |  00m00s
Complete!

    Installing org.gnome.Logs  (replaces gnome-logs)
Installing runtime/org.gnome.Logs.Locale/x86_64/stable
Installing app/org.gnome.Logs/x86_64/stable
    Removing RPM gnome-logs...
Package     Arch   Version     Repository                            Size
Removing:
 gnome-logs x86_64 45.0-5.fc42 624cbc92582d4ecfae4c58749abde4f8   1.4 MiB

Transaction Summary:
 Removing:           1 package

After this operation, 1 MiB will be freed (install 0 B, remove 1 MiB).
Running transaction
[1/2] Prepare transaction               100% |  11.0   B/s |   1.0   B |  00m00s
[2/2] Removing gnome-logs-0:45.0-5.fc42 100% | 932.0   B/s | 275.0   B |  00m00s
Complete!

    Installing org.gnome.TextEditor  (replaces gnome-text-editor)
Installing runtime/org.gnome.TextEditor.Locale/x86_64/stable
Installing app/org.gnome.TextEditor/x86_64/stable
    Removing RPM gnome-text-editor...
Package            Arch   Version        Repository      Size
Removing:
 gnome-text-editor x86_64 48.3-1.fc42    <unknown>    2.3 MiB
Removing unused dependencies:
 editorconfig-libs x86_64 0.12.10-1.fc42 <unknown>   38.2 KiB
 libspelling       x86_64 0.4.8-1.fc42   <unknown>  242.2 KiB

Transaction Summary:
 Removing:           3 packages

After this operation, 3 MiB will be freed (install 0 B, remove 3 MiB).
Running transaction
[1/4] Prepare transaction               100% |  34.0   B/s |   3.0   B |  00m00s
[2/4] Removing gnome-text-editor-0:48.3 100% |   6.9 KiB/s | 312.0   B |  00m00s
[3/4] Removing editorconfig-libs-0:0.12 100% |   1.3 KiB/s |  12.0   B |  00m00s
[4/4] Removing libspelling-0:0.4.8-1.fc 100% | 234.0   B/s |  64.0   B |  00m00s
Complete!

    Installing org.gnome.Loupe  (replaces loupe)
Installing runtime/org.gnome.Loupe.Locale/x86_64/stable
Installing app/org.gnome.Loupe/x86_64/stable
    Removing RPM loupe...
Package Arch   Version     Repository      Size
Removing:
 loupe  x86_64 48.2-1.fc42 <unknown>    7.2 MiB

Transaction Summary:
 Removing:           1 package

After this operation, 7 MiB will be freed (install 0 B, remove 7 MiB).
Running transaction
[1/2] Prepare transaction               100% |  12.0   B/s |   1.0   B |  00m00s
[2/2] Removing loupe-0:48.2-1.fc42.x86_ 100% |   1.5 KiB/s | 445.0   B |  00m00s
Complete!

    Installing org.fedoraproject.MediaWriter  (replaces mediawriter)
Installing runtime/org.kde.KStyle.Adwaita/x86_64/6.10
Installing runtime/org.kde.Platform.Locale/x86_64/6.10
Installing runtime/org.kde.Platform/x86_64/6.10
Installing app/org.fedoraproject.MediaWriter/x86_64/stable
    Removing RPM mediawriter...
Package      Arch   Version      Repository      Size
Removing:
 mediawriter x86_64 5.3.0-1.fc42 <unknown>    3.2 MiB

Transaction Summary:
 Removing:           1 package

After this operation, 3 MiB will be freed (install 0 B, remove 3 MiB).
Running transaction
[1/2] Prepare transaction               100% |  13.0   B/s |   1.0   B |  00m00s
[2/2] Removing mediawriter-0:5.3.0-1.fc 100% | 111.0   B/s |  22.0   B |  00m00s
Complete!

    Installing org.gnome.Rhythmbox3  (replaces rhythmbox)
Installing runtime/org.gnome.Rhythmbox3.Locale/x86_64/stable
Installing app/org.gnome.Rhythmbox3/x86_64/stable
    Removing RPM rhythmbox...
Package               Arch   Version        Repository                            Size
Removing:
 rhythmbox            x86_64 3.4.9-1.fc42   <unknown>                         11.8 MiB
Removing unused dependencies:
 brasero-libs         x86_64 3.12.3-14.fc42 624cbc92582d4ecfae4c58749abde4f8 939.7 KiB
 libgpod              x86_64 0.8.3-54.fc42  624cbc92582d4ecfae4c58749abde4f8 899.6 KiB
 libtomcrypt          x86_64 1.18.2-21.fc42 624cbc92582d4ecfae4c58749abde4f8 906.7 KiB
 media-player-info    noarch 23-18.fc42     624cbc92582d4ecfae4c58749abde4f8 181.2 KiB
 python3-beaker       noarch 1.12.1-9.fc42  624cbc92582d4ecfae4c58749abde4f8 482.9 KiB
 python3-crypto       x86_64 2.6.1-54.fc42  624cbc92582d4ecfae4c58749abde4f8   2.2 MiB
 python3-cryptography x86_64 44.0.0-3.fc42  624cbc92582d4ecfae4c58749abde4f8   5.0 MiB
 python3-mako         noarch 1.2.3-9.fc42   624cbc92582d4ecfae4c58749abde4f8 701.2 KiB
 python3-markupsafe   x86_64 3.0.2-2.fc42   624cbc92582d4ecfae4c58749abde4f8  55.8 KiB
 python3-paste        noarch 3.10.1-6.fc42  624cbc92582d4ecfae4c58749abde4f8   2.6 MiB
 python3-pyOpenSSL    noarch 25.0.0-1.fc42  624cbc92582d4ecfae4c58749abde4f8 685.6 KiB
 python3-setuptools   noarch 74.1.3-7.fc42  <unknown>                          8.4 MiB
 sg3_utils-libs       x86_64 1.48-5.fc42    624cbc92582d4ecfae4c58749abde4f8 301.5 KiB

Transaction Summary:
 Removing:          14 packages

After this operation, 35 MiB will be freed (install 0 B, remove 35 MiB).
Running transaction
[ 1/15] Prepare transaction             100% | 132.0   B/s |  14.0   B |  00m00s
[ 2/15] Removing python3-beaker-0:1.12. 100% |   3.1 KiB/s |  97.0   B |  00m00s
[ 3/15] Removing rhythmbox-0:3.4.9-1.fc 100% |  11.7 KiB/s | 647.0   B |  00m00s
[ 4/15] Removing python3-paste-0:3.10.1 100% |  12.7 KiB/s | 350.0   B |  00m00s
[ 5/15] Removing python3-pyOpenSSL-0:25 100% |   2.6 KiB/s |  34.0   B |  00m00s
[ 6/15] Removing python3-mako-0:1.2.3-9 100% |   5.3 KiB/s | 164.0   B |  00m00s
[ 7/15] Removing libgpod-0:0.8.3-54.fc4 100% |   1.8 KiB/s |  37.0   B |  00m00s
[ 8/15] Removing python3-crypto-0:2.6.1 100% |  13.8 KiB/s | 439.0   B |  00m00s
[ 9/15] Removing python3-setuptools-0:7 100% |  19.4 KiB/s |   1.0 KiB |  00m00s
[10/15] Removing media-player-info-0:23 100% |  12.8 KiB/s | 263.0   B |  00m00s
[11/15] Removing libtomcrypt-0:1.18.2-2 100% |   1.0 KiB/s |   7.0   B |  00m00s
[12/15] Removing sg3_utils-libs-0:1.48- 100% |   1.0 KiB/s |   8.0   B |  00m00s
[13/15] Removing python3-markupsafe-0:3 100% |   2.5 KiB/s |  23.0   B |  00m00s
[14/15] Removing python3-cryptography-0 100% |  11.5 KiB/s | 400.0   B |  00m00s
[15/15] Removing brasero-libs-0:3.12.3- 100% |  51.0   B/s |  15.0   B |  00m00s
Complete!

    Installing org.gnome.Snapshot  (replaces snapshot)
Installing runtime/org.gnome.Snapshot.Locale/x86_64/stable
Installing app/org.gnome.Snapshot/x86_64/stable
    Removing RPM snapshot...
Package         Arch   Version       Repository      Size
Removing:
 snapshot       x86_64 48.0.1-2.fc42 <unknown>    4.7 MiB
Removing unused dependencies:
 glycin-loaders x86_64 1.2.3-6.fc42  <unknown>   10.4 MiB

Transaction Summary:
 Removing:           2 packages

After this operation, 15 MiB will be freed (install 0 B, remove 15 MiB).
Running transaction
[1/3] Prepare transaction               100% |  24.0   B/s |   2.0   B |  00m00s
[2/3] Removing snapshot-0:48.0.1-2.fc42 100% |   2.3 KiB/s |  65.0   B |  00m00s
[3/3] Removing glycin-loaders-0:1.2.3-6 100% | 123.0   B/s |  30.0   B |  00m00s
Complete!
    Phase A complete.


################ PHASE B: Migrate non-Flathub Flatpaks to Flathub ################

==> Step B1/5: Scanning apps from non-Flathub remotes
    Found 0 app(s) from non-Flathub remote(s).
    Nothing to migrate.


################ PHASE C: Clean up empty remotes ################

==> Removing orphaned runtimes
Nothing unused to uninstall

==> Checking for empty non-Flathub remotes
    No non-Flathub remotes configured.


################ PHASE D: Replace GNOME Software with Bazaar ################

==> Step D1/3: Checking current state
    GNOME Software RPM is installed.
    Bazaar is not installed.

==> Step D2/3: Plan
   + install  io.github.kolunmi.Bazaar (from Flathub)
   - remove   gnome-software (via dnf)

Proceed with Phase D? [y/N] n
    Skipped Phase D.

    All done. Log: /home/test/flatpak-migrate-20260418-122336.log
