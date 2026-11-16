"""Tests for bin/nix-cljfmt's argument parsing and its pure core.

Run with `python3 -m unittest discover -s tests`; `nix flake check` runs them.
"""

import importlib.machinery
import importlib.util
import io
import json
import shutil
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "bin" / "nix-cljfmt"
_loader = importlib.machinery.SourceFileLoader("nix_cljfmt", str(TOOL))
_spec = importlib.util.spec_from_loader("nix_cljfmt", _loader)
tool = importlib.util.module_from_spec(_spec)
_loader.exec_module(tool)

SHA = "f8c7bd90b1715831f282ecff0d70c2fb24b5781c"


def deps_edn(tag="0.15.2", sha="f8c7bd9"):
    return (
        "{:deps {io.github.weavejester/cljfmt\n"
        '        {:git/url "https://github.com/weavejester/cljfmt"\n'
        f'         :git/tag "{tag}"\n'
        f'         :git/sha "{sha}"}}}}}}\n'
    )


def deps_lock(tag="0.15.2"):
    return json.dumps(
        {
            "git-deps": [
                {"lib": "org.example/other", "tag": "9.9.9"},
                {"lib": "io.github.weavejester/cljfmt", "tag": tag, "rev": SHA},
            ],
            "mvn-deps": [],
        }
    )


def flake(version="0.15.2"):
    return (
        "{\n"
        "  cljfmt-app = mkCljApp {\n"
        '    name = "cljfmt";\n'
        f'    version = "{version}";\n'
        "  };\n"
        "  check = ${cljfmt-app.version};\n"
        "}\n"
    )


def readme(version="0.15.2", link=None):
    link = link or version
    return (
        "# nix-cljfmt\n\n"
        f"This package builds [`weavejester/cljfmt {version}`]"
        f"(https://github.com/weavejester/cljfmt/releases/tag/{link}).\n"
    )


def texts(**overrides):
    base = {
        tool.DEPS_EDN: deps_edn(),
        tool.DEPS_LOCK: deps_lock(),
        tool.FLAKE: flake(),
        tool.README: readme(),
    }
    base.update(overrides)
    return base


class ReadVersionsTest(unittest.TestCase):
    def test_reads_each_file(self):
        self.assertEqual(
            tool.versions(texts()),
            {name: "0.15.2" for name in tool.FILES},
        )

    def test_lock_finds_cljfmt_among_other_git_deps(self):
        self.assertEqual(tool.deps_lock_version(deps_lock("0.14.0")), "0.14.0")

    def test_lock_without_cljfmt_or_not_json(self):
        self.assertIsNone(tool.deps_lock_version('{"git-deps": []}'))
        self.assertIsNone(tool.deps_lock_version("not json"))

    def test_flake_ignores_interpolated_version(self):
        self.assertIsNone(tool.flake_version("x = ${cljfmt-app.version};"))

    def test_readme_with_disagreeing_link_states_no_version(self):
        self.assertIsNone(tool.readme_version(readme("0.15.2", link="0.14.0")))


class DisagreementsTest(unittest.TestCase):
    def test_agreeing_files(self):
        self.assertEqual(tool.disagreements(tool.versions(texts())), [])

    def test_names_each_stale_file(self):
        found = tool.versions(
            texts(**{tool.README: readme("0.14.0"), tool.DEPS_LOCK: deps_lock("0.15.1")})
        )
        problems = tool.disagreements(found)
        self.assertEqual(len(problems), 2)
        self.assertTrue(problems[0].startswith("deps-lock.json: states 0.15.1"))
        self.assertTrue(problems[1].startswith("README.md: states 0.14.0"))

    def test_missing_tag(self):
        found = tool.versions(texts(**{tool.DEPS_EDN: "{:deps {}}"}))
        self.assertEqual(tool.disagreements(found), ["deps.edn: no :git/tag found"])


class BumpTest(unittest.TestCase):
    def test_rewrites_hand_edited_files(self):
        new = tool.bumped_texts(texts(), "0.16.0", "abcdef0123456789")
        self.assertEqual(new[tool.DEPS_EDN], deps_edn("0.16.0", "abcdef0"))
        self.assertEqual(new[tool.FLAKE], flake("0.16.0"))
        self.assertEqual(new[tool.README], readme("0.16.0"))
        self.assertNotIn(tool.DEPS_LOCK, new)

    def test_refuses_a_file_without_its_marker(self):
        with self.assertRaises(tool.ToolError):
            tool.bumped_texts(texts(**{tool.README: "# nothing here\n"}), "0.16.0", SHA)

    def test_refuses_an_ambiguous_flake(self):
        with self.assertRaises(tool.ToolError):
            tool.bumped_texts(texts(**{tool.FLAKE: flake() + flake()}), "0.16.0", SHA)

    def test_diff_names_the_file(self):
        out = tool.diff("flake.nix", flake(), flake("0.16.0"))
        self.assertIn("--- a/flake.nix", out)
        self.assertIn('+    version = "0.16.0";', out)


class TagShaTest(unittest.TestCase):
    def test_prefers_peeled_commit_of_annotated_tag(self):
        output = (
            "1111111111111111111111111111111111111111\trefs/tags/0.15.2\n"
            f"{SHA}\trefs/tags/0.15.2^{{}}\n"
        )
        self.assertEqual(tool.tag_sha(output, "0.15.2"), SHA)

    def test_lightweight_tag(self):
        self.assertEqual(tool.tag_sha(f"{SHA}\trefs/tags/0.15.2\n", "0.15.2"), SHA)

    def test_missing_tag(self):
        with self.assertRaises(tool.ToolError):
            tool.tag_sha("", "9.9.9")

    def test_valid_sha(self):
        self.assertTrue(tool.valid_sha("f8c7bd9"))
        self.assertFalse(tool.valid_sha("0.15.2"))


class ParserTest(unittest.TestCase):
    def parse(self, *argv):
        return tool.build_parser().parse_args(list(argv))

    def test_version_options(self):
        args = self.parse("version", "--check", "--json")
        self.assertEqual((args.command, args.check, args.json), ("version", True, True))

    def test_bump_options(self):
        args = self.parse("--root", "/r", "bump", "0.16.0", "--sha", "abc1234", "--no-lock", "--dry-run")
        self.assertEqual(args.root, Path("/r"))
        self.assertEqual(
            (args.command, args.version, args.sha, args.no_lock, args.dry_run),
            ("bump", "0.16.0", "abc1234", True, True),
        )

    def test_lock_dry_run(self):
        self.assertTrue(self.parse("lock", "--dry-run").dry_run)

    def test_bad_usage_exits_2(self):
        for argv in ([], ["bump"], ["frobnicate"], ["version", "--nope"]):
            with self.subTest(argv=argv), redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as raised:
                    self.parse(*argv)
                self.assertEqual(raised.exception.code, 2)

    def test_help_lists_command_tokens(self):
        text = tool.build_parser().format_help()
        for token in ("version", "bump", "lock", "--root"):
            self.assertIn(token, text)


class MainTest(unittest.TestCase):
    """main() over a scratch repository, with no network or nix."""

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        for name, text in texts().items():
            (self.root / name).write_text(text)

    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = tool.main(["--root", str(self.root), *argv])
        return code, out.getvalue(), err.getvalue()

    def test_version_check_passes_then_fails_on_stale_readme(self):
        self.assertEqual(self.run_main("version", "--check")[0], 0)
        (self.root / tool.README).write_text(readme("0.14.0"))
        code, _, err = self.run_main("version", "--check")
        self.assertEqual(code, 1)
        self.assertIn("README.md", err)

    def test_bump_writes_files_and_leaves_lock_stale(self):
        code, _, _ = self.run_main("bump", "0.16.0", "--sha", SHA, "--no-lock")
        self.assertEqual(code, 0)
        found = tool.versions(tool.read_texts(self.root))
        self.assertEqual(found[tool.FLAKE], "0.16.0")
        self.assertEqual(found[tool.DEPS_LOCK], "0.15.2")

    def test_bump_dry_run_writes_nothing(self):
        before = tool.read_texts(self.root)
        code, out, _ = self.run_main("bump", "0.16.0", "--sha", SHA, "--dry-run")
        self.assertEqual(code, 0)
        self.assertIn("+++ b/deps.edn", out)
        self.assertIn("would run", out)
        self.assertEqual(tool.read_texts(self.root), before)

    def test_bad_sha_fails(self):
        self.assertEqual(self.run_main("bump", "0.16.0", "--sha", "nope", "--no-lock")[0], 1)

    def test_missing_files_fail(self):
        (self.root / tool.FLAKE).unlink()
        code, _, err = self.run_main("version")
        self.assertEqual(code, 1)
        self.assertIn("flake.nix", err)


if __name__ == "__main__":
    unittest.main()
