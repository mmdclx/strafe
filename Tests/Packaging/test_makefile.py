"""Exercise the real Makefile with isolated build/sign/launch tool stand-ins."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]
MAKEFILE = Path(os.environ.get("STRAFE_TEST_MAKEFILE", REPO / "Makefile"))
TOOLS = r'''
import json
from pathlib import Path
import shutil
import sys

root = Path.cwd()
name, args = Path(sys.argv[0]).name, sys.argv[1:]
with (root / "calls.jsonl").open("a") as log:
    log.write(json.dumps([name, *args]) + "\n")
if name == "swift":
    config = args[args.index("-c") + 1]
    output = root / "swift output" / config
    if "--show-bin-path" in args:
        print(output)
        sys.exit(2 if (root / "fail-path").exists() else 0)
    source = (root / "source.swift").read_text()
    if source == "broken":
        sys.exit("simulated compilation failure")
    output.mkdir(parents=True, exist_ok=True)
    (output / "Strafe").write_text(config + ":" + source)
    framework = output / "OpenMultitouchSupportXCF.framework"
    framework.mkdir(exist_ok=True)
    (framework / "embedded").write_text(config + ":" + source)
elif name == "ditto":
    if "-c" in args:
        source, destination = map(Path, args[-2:])
        destination.write_bytes((source / "Contents/MacOS/Strafe").read_bytes())
    else:
        shutil.copytree(*args, dirs_exist_ok=True)
elif name == "otool":
    print("@executable_path/../Frameworks")
elif name == "codesign" and (root / "fail-sign").exists():
    sys.exit("simulated signing failure")
'''


class BuildFlowTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="strafe build ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        shutil.copyfile(MAKEFILE, self.root / "Makefile")
        resources = self.root / "Resources"
        resources.mkdir()
        (resources / "Info.plist").write_bytes(plistlib.dumps({"CFBundleShortVersionString": "0.0.1"}))
        (resources / "Strafe.icns").write_bytes(b"icon fixture")
        tools = self.root / "tools"
        tools.mkdir()
        for name in ("swift", "ditto", "codesign", "otool", "install_name_tool", "open"):
            tool = tools / name
            tool.write_text("#!" + sys.executable + "\n" + TOOLS)
            tool.chmod(0o755)
        self.env = dict(os.environ, PATH=str(tools) + os.pathsep + os.environ["PATH"])
        for key in ("CONFIG", "MAKEFLAGS", "MFLAGS", "MAKEOVERRIDES"):
            self.env.pop(key, None)
        self.source = self.root / "source.swift"
        self.source.write_text("first")
        self.bundle = self.root / "build/Strafe.app"
        self.binary = self.bundle / "Contents/MacOS/Strafe"
        self.archive = self.root / "build/Strafe-0.0.1-macos.zip"

    def make(self, target="build", config=None, success=True):
        args = ["make", "--no-print-directory", target]
        if config:
            args.append("CONFIG=" + config)
        result = subprocess.run(args, cwd=self.root, env=self.env, capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertNotIn("Created ", result.stdout)
        return result

    def calls(self):
        return [json.loads(line) for line in (self.root / "calls.jsonl").read_text().splitlines()]

    def test_source_changes_reach_every_build_entry_point(self):
        for target, config, expected in [("build", None, "debug"), ("build", "release", "release"),
                                          ("run", None, "debug"), ("package-release", None, "release")]:
            with self.subTest(target=target, config=config):
                self.source.write_text("first")
                self.make(target, config)
                self.source.write_text("changed")
                self.make(target, config)
                content = expected + ":changed"
                self.assertEqual(self.binary.read_text(), content)
                self.assertEqual((self.bundle / "Contents/Frameworks/OpenMultitouchSupportXCF.framework/embedded").read_text(), content)
                self.assertEqual((self.bundle / "Contents/Resources/Strafe.icns").read_bytes(), b"icon fixture")
                if target == "run":
                    self.assertEqual(self.calls()[-1][0], "open")
                if target == "package-release":
                    self.assertEqual(self.archive.read_text(), content)
                    checksum = (self.root / "build/SHA256SUMS.txt").read_text().split()[0]
                    self.assertEqual(checksum, hashlib.sha256(self.archive.read_bytes()).hexdigest())

    def test_failed_compilation_cannot_reuse_cached_binary(self):
        self.make("package-release")
        original_binary, original_archive = self.binary.read_bytes(), self.archive.read_bytes()
        self.source.write_text("broken")
        for target in ("build", "run", "package-release"):
            with self.subTest(target=target):
                before = len(self.calls())
                self.make(target, config="release", success=False)
                self.assertEqual(self.binary.read_bytes(), original_binary)
                self.assertEqual(self.archive.read_bytes(), original_archive)
                self.assertTrue(all(call[0] == "swift" for call in self.calls()[before:]))

    def test_failed_first_build_leaves_no_bundle(self):
        self.source.write_text("broken")
        self.make(success=False)
        self.assertFalse(self.bundle.exists())

    def test_failed_path_lookup_cannot_continue_with_its_stdout(self):
        self.make("package-release")
        original = self.binary.read_bytes()
        self.source.write_text("changed")
        (self.root / "fail-path").touch()
        self.make("package-release", success=False)
        self.assertEqual(self.binary.read_bytes(), original)
        self.assertEqual(self.archive.read_bytes(), original)

    def test_failed_signing_does_not_publish_a_package(self):
        self.make("package-release")
        original = self.archive.read_bytes()
        self.source.write_text("changed")
        (self.root / "fail-sign").touch()
        self.make("package-release", success=False)
        self.assertEqual(self.archive.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
