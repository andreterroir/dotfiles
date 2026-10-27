import json
import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile
import tomllib
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1]
CHEZMOI = shutil.which("chezmoi")


class VMTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.config = self.home / "chezmoi.toml"
        self.config.write_text('[data]\ndesktop = true\nserver = false\nlinux.desktop = true\n')

    def chezmoi(self, vm, *args, text=None, desktop=True, os_name="linux", arch=None):
        data = {"vm": vm, "desktop": desktop, "server": not desktop,
                "linux": {"desktop": desktop and os_name == "linux"},
                "passage": desktop and not vm,
                "chezmoi": {"os": os_name, "homeDir": str(self.home),
                            "osRelease": {"id": "fedora"} if os_name == "linux" else {}}}
        if arch is not None:
            data["chezmoi"]["arch"] = arch
        return subprocess.run(
            [CHEZMOI, "--source", str(SOURCE), "--destination", str(self.home),
             "--config", str(self.config), "--persistent-state", str(self.home / "state.db"),
             "--override-data", json.dumps(data), *args],
            input=text, text=True, capture_output=True, check=True,
        ).stdout

    def render(self, vm, path, **kwargs):
        return self.chezmoi(vm, "execute-template", text=(SOURCE / path).read_text(), **kwargs)

    def test_fedora_flatpaks_match_architecture(self):
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        for command in ("sudo", "rpm", "curl", "git", "go"):
            stub = bin_dir / command
            stub.write_text("#!/bin/sh\nexit 0\n")
            stub.chmod(0o755)
        flatpak = bin_dir / "flatpak"
        flatpak.write_text('''#!/bin/sh
set -eu
for app do
    case "$app" in install|--assumeyes) continue ;; esac
    if [ "$app" = com.spotify.Client ] && [ "$TEST_ARCH" != amd64 ]; then
        echo "No remote refs found for $app" >&2
        exit 1
    fi
    mkdir -p "$HOME/installed"
    touch "$HOME/installed/$app"
done
''')
        flatpak.chmod(0o755)
        for vm in (False, True):
            for arch in ("arm64", "amd64"):
                with self.subTest(vm=vm, arch=arch):
                    script = self.render(vm, "run_onchange_install-linux-packages.sh.tmpl", arch=arch)
                    home = self.home / f"machine-{vm}-{arch}"
                    home.mkdir()
                    env = dict(os.environ, HOME=str(home), TEST_ARCH=arch,
                               PATH=f"{bin_dir}:{os.environ['PATH']}")
                    subprocess.run(["bash", "-c", script], env=env, check=True, capture_output=True)
                    installed = {path.name for path in (home / "installed").iterdir()}
                    expected = {"md.obsidian.Obsidian", "org.signal.Signal",
                                "org.telegram.desktop", "org.zotero.Zotero"}
                    if arch == "amd64":
                        expected.add("com.spotify.Client")
                    self.assertEqual(installed, expected)

    def test_password_store_is_not_provisioned(self):
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        for os_name, desktop in (("linux", True), ("linux", False), ("darwin", True)):
            gnome = bin_dir / "gnome-shell"
            gnome.unlink(missing_ok=True)
            if desktop:
                gnome.symlink_to("/bin/true")
            for vm in (False, True):
                with self.subTest(os=os_name, desktop=desktop, vm=vm):
                    enabled = desktop and not vm
                    options = {"desktop": desktop, "os_name": os_name}
                    managed = set(self.chezmoi(vm, "managed", **options).splitlines())
                    for path in ("20-passage-install.sh", "20-passage-store.sh",
                                 "21-passage-identities.sh", ".passage/plugin-identities"):
                        self.assertEqual(path in managed, enabled, path)
                    for path in ("dot_bin/executable_update-passwords.tmpl",
                                 "run_after_20-passage-store.sh.tmpl",
                                 "run_after_21-passage-identities.sh.tmpl",
                                 "run_onchange_after_20-passage-install.sh.tmpl",
                                 "private_dot_passage/plugin-identities.tmpl"):
                        self.assertEqual(bool(self.render(vm, path, **options).strip()), enabled, path)
                    with patch.dict(os.environ, {"PATH": str(bin_dir)}):
                        config = tomllib.loads(self.render(vm, ".chezmoi.toml.tmpl", **options))
                    self.assertEqual("hooks" in config, enabled)
                    self.assertEqual(config["data"]["vm"], vm)
                    self.assertEqual(config["data"]["passage"], enabled)
                    packages = self.render(vm, "run_onchange_install-macos-packages.sh.tmpl", **options)
                    self.assertEqual("brew 'age-plugin-yubikey'" in packages, enabled and os_name == "darwin")
                    mise = self.render(vm, "private_dot_config/mise/config.toml.tmpl", **options)
                    self.assertEqual("cargo:age-plugin-yubikey" in mise, enabled and os_name == "linux")

    def test_macos_passage_install_uses_diskutil_for_its_ramdisk(self):
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        git = bin_dir / "git"
        git.write_text('''#!/bin/sh
set -eu
if [ "$1" = clone ]; then
    for target; do :; done
    mkdir -p "$target/src/platform"
    cat > "$target/src/platform/darwin.sh" <<'EOF'
DARWIN_RAMDISK_DEV="$(hdid -drivekey system-image=yes -nomount 'ram://32768' | cut -d ' ' -f 1)"
EOF
elif [ "$1" = -C ] && [ "$3" = checkout ]; then
    : > "$2/otp.bash"
    : > "$2/pass-otp.bash.completion"
fi
''')
        git.chmod(0o755)
        make = bin_dir / "make"
        make.write_text('''#!/bin/sh
set -eu
source=$2
grep -Fq "diskutil image attach --noMount 'ram://32768' | cut -f 1" "$source/src/platform/darwin.sh"
''')
        make.chmod(0o755)
        script = self.render(False, "run_onchange_after_20-passage-install.sh.tmpl",
                             desktop=True, os_name="darwin")
        result = subprocess.run(["bash", "-c", script],
                                env=dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}"),
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_vm_migration_preserves_local_secrets(self):
        root = self.home
        for desktop, vm in ((True, True), (False, False), (False, True)):
            with self.subTest(desktop=desktop, vm=vm):
                self.home = root / f"machine-{desktop}-{vm}"
                passage = self.home / ".passage"
                (passage / "store").mkdir(parents=True)
                (self.home / ".bin").mkdir()
                for path in (".passage/plugin-identities", ".passage/identities",
                             ".passage/local-identities", ".passage/store/secret.age",
                             ".bin/update-passwords"):
                    (self.home / path).write_text("keep local data\n")
                self.chezmoi(vm, "apply", "--exclude", "scripts", desktop=desktop)
                self.assertFalse((passage / "plugin-identities").exists())
                self.assertFalse((self.home / ".bin/update-passwords").exists())
                for path in ("identities", "local-identities", "store/secret.age"):
                    self.assertEqual((passage / path).read_text(), "keep local data\n")

    def test_stale_policy_requires_init(self):
        command = [CHEZMOI, "--source", str(SOURCE), "--destination", str(self.home),
                   "--config", str(self.config), "--persistent-state", str(self.home / "state.db")]
        for desktop, vm, passage in ((True, True, None), (True, True, True),
                                     (False, False, True), (True, False, False)):
            with self.subTest(desktop=desktop, vm=vm, passage=passage):
                data = {"desktop": desktop, "server": not desktop,
                        "linux.desktop": desktop, "vm": vm}
                if passage is not None:
                    data["passage"] = passage
                self.config.write_text(
                    '[hooks.update.post]\ncommand = "false"\n[data]\n'
                    + "".join(f"{key} = {str(value).lower()}\n" for key, value in data.items())
                )
                result = subprocess.run(command + ["apply", "--exclude", "scripts"],
                                        text=True, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("run chezmoi init", result.stderr)
                self.assertFalse((self.home / ".gitconfig").exists())
                subprocess.run(command + ["init", "--no-tty"],
                               check=True, capture_output=True)
                regenerated = tomllib.loads(self.config.read_text())
                self.assertEqual(regenerated["data"]["vm"], vm)
                expected = regenerated["data"]["desktop"] and not vm
                self.assertEqual(regenerated["data"]["passage"], expected)
                self.assertEqual("hooks" in regenerated, expected)
                subprocess.run(command + ["apply", "--dry-run", "--exclude", "scripts"],
                               check=True, capture_output=True)

    def test_vm_ssh_identity_filter(self):
        self.chezmoi(True, "apply", "--exclude", "scripts")
        for host in ("github.com", "git.terroir.systems", "chalon"):
            with self.subTest(host=host):
                config = subprocess.check_output(
                    ["ssh", "-G", "-F", str(self.home / ".ssh/config"), host],
                    text=True, stderr=subprocess.DEVNULL,
                ).splitlines()
                self.assertIn("identitiesonly yes", config)
                self.assertEqual("identityfile ~/.ssh/id_ed25519" in config,
                                 host == "github.com")
                for index in (1, 2):
                    path = f".ssh/identities/yubikey-{index}"
                    self.assertIn(f"identityfile ~/{path}", config)
                    key = (self.home / path).read_text()
                    self.assertTrue(key.startswith("sk-ssh-ed25519@openssh.com "))
                    subprocess.run(["ssh-keygen", "-l", "-f", str(self.home / path)],
                                   check=True, capture_output=True)

    def test_vm_and_server_bootstrap_without_terminal_or_yubikey(self):
        root = self.home
        for desktop, vm in ((True, True), (False, True), (False, False)):
            with self.subTest(desktop=desktop, vm=vm):
                self.home = root / f"machine-{desktop}-{vm}"
                (self.home / ".ssh").mkdir(parents=True)
                script = self.render(vm, "run_after_10-ssh-identity.sh.tmpl", desktop=desktop)
                env = dict(os.environ, HOME=str(self.home))
                private = self.home / ".ssh/id_ed25519"
                for _ in range(2):
                    result = subprocess.run(["bash", "-c", script], env=env,
                                            stdin=subprocess.DEVNULL, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("machine key ready", result.stderr)
                    public = subprocess.check_output(
                        ["ssh-keygen", "-y", "-P", "", "-f", str(private)], text=True)
                    self.assertEqual(public.strip(), private.with_suffix(".pub").read_text().strip())
                self.assertFalse((self.home / ".ssh/id_ed25519_sk").exists())

    def test_encrypted_machine_keys_are_preserved_with_migration_instructions(self):
        (self.home / ".ssh").mkdir()
        private = self.home / ".ssh/id_ed25519"
        subprocess.run(["ssh-keygen", "-t", "ed25519", "-N", "test-passphrase",
                        "-f", str(private)], check=True, capture_output=True)
        before = private.read_bytes(), private.with_suffix(".pub").read_bytes()
        for desktop, vm in ((True, True), (False, True), (False, False)):
            with self.subTest(desktop=desktop, vm=vm):
                script = self.render(vm, "run_after_10-ssh-identity.sh.tmpl", desktop=desktop)
                result = subprocess.run(["bash", "-c", script], env=dict(os.environ, HOME=str(self.home)),
                                        stdin=subprocess.DEVNULL, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("ssh-keygen -p", result.stderr)
                self.assertIn("leave the new passphrase empty", result.stderr)
                self.assertEqual((private.read_bytes(), private.with_suffix(".pub").read_bytes()), before)

    def test_passwordless_sudo_is_vm_only_and_validated_before_activation(self):
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        sudo = bin_dir / "sudo"
        sudo.write_text('''#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import sys

args = sys.argv[1:]
if args == ["-k", "-n", "true"]:
    sys.exit(0 if (Path(os.environ["TEST_SUDO_DIR"]) / f"99-chezmoi-{os.getuid()}").exists() else 1)
if args[:3] == ["install", "-o", "root"]:
    del args[1:3]
args = [str(Path(os.environ["TEST_SUDO_DIR"]) / Path(arg).name)
        if arg.startswith("/etc/sudoers.d/") else arg for arg in args]
if args[0] == "visudo" and os.environ.get("TEST_REJECT_POLICY"):
    sys.exit(1)
sys.exit(subprocess.run(args).returncode)
''')
        sudo.chmod(0o755)
        for os_name, desktop in (("linux", True), ("linux", False), ("darwin", True)):
            for vm in (False, True):
                with self.subTest(os=os_name, desktop=desktop, vm=vm):
                    script = self.render(vm, "run_onchange_before_00-vm-sudo.sh.tmpl",
                                         desktop=desktop, os_name=os_name)
                    self.assertEqual(bool(script.strip()), vm)
                    directory = self.home / f"sudoers-{os_name}-{desktop}-{vm}"
                    directory.mkdir()
                    env = dict(os.environ, TEST_SUDO_DIR=str(directory),
                               PATH=f"{bin_dir}:{os.environ['PATH']}")
                    for _ in range(2):
                        subprocess.run(["bash", "-c", script], env=env,
                                       check=True, capture_output=True)
                    policy = directory / f"99-chezmoi-{os.getuid()}"
                    if not vm:
                        self.assertEqual(list(directory.iterdir()), [])
                        continue
                    expected = f"#{os.getuid()} ALL=(ALL:ALL) NOPASSWD: ALL\n"
                    self.assertEqual(policy.read_text(), expected)
                    self.assertEqual(policy.stat().st_mode & 0o777, 0o440)
                    policy.chmod(0o600)
                    policy.write_text("# Existing policy must survive failed validation\n")
                    result = subprocess.run(["bash", "-c", script],
                                            env=dict(env, TEST_REJECT_POLICY="1"), capture_output=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(policy.read_text(), "# Existing policy must survive failed validation\n")

    def test_machine_signing_and_repository_override(self):
        (self.home / ".ssh").mkdir()
        machine = self.home / ".ssh/id_ed25519"
        override = self.home / ".ssh/override"
        for key in (machine, override):
            subprocess.run(["ssh-keygen", "-t", "ed25519", "-N", "", "-f", str(key)],
                           check=True, capture_output=True)
        fingerprints = {
            key: subprocess.check_output(["ssh-keygen", "-lf", str(key)], text=True).split()[1]
            for key in (machine, override)
        }
        allowed = self.home / ".allowed_signers"
        allowed.write_text("".join(
            "andre@terroir.systems " + key.with_suffix(".pub").read_text()
            for key in (machine, override)
        ))
        env = dict(os.environ, HOME=str(self.home), GIT_CONFIG_NOSYSTEM="1",
                   GIT_CONFIG_GLOBAL=str(self.home / ".gitconfig"),
                   SSH_AUTH_SOCK=str(self.home / "missing-agent"), SSH_ASKPASS_REQUIRE="never")
        repository = self.home / "repository"
        subprocess.run(["git", "init", str(repository)], env=env, check=True, capture_output=True)

        def git(*args, **kwargs):
            return subprocess.run(["git", "-C", str(repository), *args], env=env,
                                  text=True, capture_output=True, **kwargs)

        master, terminal = pty.openpty()
        self.addCleanup(os.close, master)
        self.addCleanup(os.close, terminal)
        for os_name, desktop in (("linux", True), ("linux", False), ("darwin", True)):
            for vm in (False, True):
                (self.home / ".gitconfig").write_text(
                    self.render(vm, "dot_gitconfig.tmpl", desktop=desktop, os_name=os_name))
                for interactive in (False, True):
                    with self.subTest(os=os_name, desktop=desktop, vm=vm, interactive=interactive):
                        result = git("commit", "--allow-empty", "-m", "Machine signature",
                                     stdin=terminal if interactive else subprocess.DEVNULL)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        signature = git("verify-commit", "HEAD", check=True)
                        self.assertIn(fingerprints[machine], signature.stderr)

        agent = subprocess.check_output(["ssh-agent", "-s"], text=True)
        agent_env = dict(env)
        for assignment in agent.splitlines()[:2]:
            key, value = assignment.split(";", 1)[0].split("=", 1)
            agent_env[key] = value
        self.addCleanup(subprocess.run, ["ssh-agent", "-k"], env=agent_env, capture_output=True)
        subprocess.run(["ssh-add", str(override)], env=agent_env, check=True, capture_output=True)
        override.unlink()
        env["SSH_AUTH_SOCK"] = agent_env["SSH_AUTH_SOCK"]
        git("commit", "--allow-empty", "-m", "Unrelated forwarded agent", check=True)
        self.assertIn(fingerprints[machine], git("verify-commit", "HEAD", check=True).stderr)

        git("config", "--local", "user.signingKey", str(override.with_suffix(".pub")), check=True)
        git("commit", "--allow-empty", "-m", "Explicit signing override", check=True)
        self.assertIn(fingerprints[override], git("verify-commit", "HEAD", check=True).stderr)
        head = git("rev-parse", "HEAD", check=True).stdout
        env["SSH_AUTH_SOCK"] = str(self.home / "missing-agent")
        result = git("commit", "--allow-empty", "-m", "Unavailable override",
                     stdin=subprocess.DEVNULL)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(git("rev-parse", "HEAD", check=True).stdout, head)

        git("config", "--local", "--unset", "user.signingKey", check=True)
        git("commit", "--allow-empty", "-m", "Back to machine signing", check=True)
        self.assertIn(fingerprints[machine], git("verify-commit", "HEAD", check=True).stderr)

        subprocess.run(["ssh-add", str(machine)], env=agent_env, check=True, capture_output=True)
        subprocess.run(["ssh-keygen", "-p", "-P", "", "-N", "test-passphrase", "-f", str(machine)],
                       check=True, capture_output=True)
        env["SSH_AUTH_SOCK"] = agent_env["SSH_AUTH_SOCK"]
        git("commit", "--allow-empty", "-m", "Unlocked encrypted desktop key", check=True)
        self.assertIn(fingerprints[machine], git("verify-commit", "HEAD", check=True).stderr)

    def test_signing_selector_is_retired(self):
        selector = self.home / ".bin/git-signing-key"
        selector.parent.mkdir()
        selector.write_text("obsolete selector\n")
        self.chezmoi(True, "apply", "--exclude", "scripts")
        self.assertFalse(selector.exists())


if __name__ == "__main__":
    unittest.main()
