import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import check_milestones


class MilestoneCheckTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        (self.root / "packages").mkdir()
        (self.root / "config").mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def write_package(self, name, milestones, master=None):
        package = self.root / "packages" / name
        package.mkdir()
        lines = [f"milestones='{milestones}'"]
        if master:
            lines.append(f"master='{master}'")
        (package / "package.desc").write_text("\n".join(lines) + "\n")

    def write_config(self, relative_path, text):
        path = self.root / "config" / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text + "\n")

    def test_reports_undeclared_milestone(self):
        self.write_package("foo", "1.0")
        self.write_config("foo.in", "config FOO\n\tselect FOO_REQUIRE_2_0_or_later")

        self.assertEqual(
            check_milestones.find_unresolved(self.root),
            [("config/foo.in", "FOO_REQUIRE_2_0_or_later", "foo", "2_0")],
        )

    def test_accepts_declared_milestone(self):
        self.write_package("foo", "1.0 2.0")
        self.write_config("foo.in", "config FOO\n\tselect FOO_REQUIRE_2_0_or_later")

        self.assertEqual(check_milestones.find_unresolved(self.root), [])

    def test_maps_fork_to_master_milestones(self):
        self.write_package("foo", "1.0")
        self.write_package("foo-fork", "", master="foo")
        self.write_config("foo.in", "config FOO\n\tselect FOO_REQUIRE_1_0_or_later")

        self.assertEqual(check_milestones.find_unresolved(self.root), [])

    def test_ignores_generated_kconfig(self):
        self.write_package("foo", "1.0")
        self.write_config("gen/foo.in", "config FOO\n\tselect FOO_REQUIRE_2_0_or_later")
        self.write_config("versions/foo.in", "config FOO\n\tselect FOO_REQUIRE_2_0_or_later")

        self.assertEqual(check_milestones.find_unresolved(self.root), [])

    def test_reports_every_milestone_symbol_form(self):
        self.write_package("foo", "1.0")
        self.write_config(
            "foo.in",
            "\n".join(
                [
                    "select FOO_2_0_or_later",
                    "select FOO_2_0_or_older",
                    "select FOO_later_than_2_0",
                    "select FOO_older_than_2_0",
                    "select FOO_REQUIRE_2_0_or_later",
                    "select FOO_REQUIRE_2_0_or_older",
                    "select FOO_REQUIRE_later_than_2_0",
                    "select FOO_REQUIRE_older_than_2_0",
                ]
            ),
        )

        reported = {entry[1] for entry in check_milestones.find_unresolved(self.root)}
        self.assertEqual(
            reported,
            {
                "FOO_2_0_or_later",
                "FOO_2_0_or_older",
                "FOO_later_than_2_0",
                "FOO_older_than_2_0",
                "FOO_REQUIRE_2_0_or_later",
                "FOO_REQUIRE_2_0_or_older",
                "FOO_REQUIRE_later_than_2_0",
                "FOO_REQUIRE_older_than_2_0",
            },
        )


if __name__ == "__main__":
    unittest.main()
