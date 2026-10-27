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

    def chezmoi(self, vm, *args, text=None, desktop=True, os_name="linux"):
        data = {"vm": vm, "desktop": desktop, "server": not desktop,
                "linux": {"desktop": desktop and os_name == "linux"},
                "passage": desktop and not vm,
                "chezmoi": {"os": os_name, "osRelease": {"id": "fedora"} if os_name == "linux" else {}}}
        return subprocess.run(
            [CHEZMOI, "--source", str(SOURCE), "--destination", str(self.home),
             "--config", str(self.config), "--persistent-state", str(self.home / "state.db"),
             "--override-data", json.dumps(data), *args],
            input=text, text=True, capture_output=True, check=True,
        ).stdout

    def render(self, vm, path, **kwargs):
        return self.chezmoi(vm, "execute-template", text=(SOURCE / path).read_text(), **kwargs)

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

    def test_vm_bootstrap_needs_neither_terminal_nor_yubikey(self):
        (self.home / ".ssh").mkdir()
        script = self.render(True, "run_after_10-ssh-identity.sh.tmpl")
        env = dict(os.environ, HOME=str(self.home))
        for _ in range(2):
            result = subprocess.run(["bash", "-c", script], env=env,
                                    stdin=subprocess.DEVNULL, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("machine key ready", result.stderr)
        private = self.home / ".ssh/id_ed25519"
        public = subprocess.check_output(["ssh-keygen", "-y", "-P", "", "-f", str(private)], text=True)
        self.assertEqual(public.strip(), private.with_suffix(".pub").read_text().strip())
        self.assertFalse((self.home / ".ssh/id_ed25519_sk").exists())

    def test_signing_with_and_without_optional_yubikey(self):
        (self.home / ".ssh").mkdir()
        machine_key = "ssh-ed25519 AAAATEST machine"
        (self.home / ".ssh/id_ed25519.pub").write_text(machine_key + "\n")
        approved = json.loads(self.chezmoi(True, "execute-template", "{{ .approvedYubiKeys | toJson }}"))
        shim = self.home / "ssh-add"
        shim.write_text('#!/bin/sh\nprintf "%s\\n" "$TEST_AGENT_KEYS"\n')
        shim.chmod(0o755)
        master, terminal = pty.openpty()
        self.addCleanup(os.close, master)
        self.addCleanup(os.close, terminal)
        for desktop, vm in ((True, False), (False, False), (True, True), (False, True)):
            selector = self.home / "git-signing-key"
            selector.write_text(self.render(vm, "dot_bin/executable_git-signing-key.tmpl", desktop=desktop))
            selector.chmod(0o755)
            for agent_key in ("", "ssh-ed25519 AAAAUNAPPROVED", *approved):
                for interactive in (False, True):
                    with self.subTest(desktop=desktop, vm=vm, key=agent_key, interactive=interactive):
                        env = dict(os.environ, HOME=str(self.home),
                                   PATH=f"{self.home}:{os.environ['PATH']}",
                                   TEST_AGENT_KEYS=agent_key)
                        env.pop("GIT_SIGNING_KEY", None)
                        result = subprocess.run(
                            [str(selector)], env=env, text=True, capture_output=True,
                            stdin=terminal if interactive else subprocess.DEVNULL,
                        )
                        if interactive and agent_key in approved:
                            self.assertEqual(result.returncode, 0, result.stderr)
                            self.assertEqual(result.stdout.strip(), "key::" + agent_key)
                        elif interactive and not vm:
                            self.assertNotEqual(result.returncode, 0)
                            self.assertIn("no authorized resident YubiKey", result.stderr)
                        else:
                            self.assertEqual(result.returncode, 0, result.stderr)
                            self.assertEqual(result.stdout.strip(), machine_key)


if __name__ == "__main__":
    unittest.main()
