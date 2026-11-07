# Fedora upgrades

Fedora desktops upgrade in place with dnf5's `system-upgrade` command; replace
both release numbers for the next upgrade:

    sudo dnf upgrade --refresh
    sudo systemctl reboot

After the reboot, download the new release and start the offline upgrade:

    sudo dnf system-upgrade download --releasever=45
    sudo dnf system-upgrade reboot

Then re-apply the configuration. It installs the package set, including
`remove-retired-packages`:

    chezmoi apply

Fedora retires packages between releases. Once the configuration is applied,
drop the packages retired since the old release:

    sudo remove-retired-packages 44

Terra tracks `$releasever`, so it follows the upgrade without changes; the
other third-party repositories on the machine are release-independent or do
the same. `run_onchange_` scripts run only when their content changes, and
the GNOME Shell extension script records the Fedora release, so this apply
downloads the Night Theme Switcher build for the new shell. Log out and back
in so the Shell loads it, then confirm with:

    gnome-extensions info nightthemeswitcher@romainvigier.fr

Since Fedora 45, oo7 provides the Secret Service instead of GNOME Keyring,
and an upgraded machine can keep both running. gcr-ssh-agent keeps the
machine key's passphrase in that service, so check which daemon answers with
`busctl --user status org.freedesktop.secrets`.
