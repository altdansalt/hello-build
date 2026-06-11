"""Unit test for check_port's vacuity detection (ADR 0010).

Both aliasing directions must be rejected:
- bazel_* defined by a legacy wrapper (coreutils scale probe, 2026-06-11)
- legacy_* defined by a Bazel-native rule (bzip2 haiku probe, 2026-06-11)
and a well-formed port must pass.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import repo_contract_test as rct

README_OK = "\n".join(
    "# x\n## %s\nbody" % s
    for s in ("Targets", "Build profile", "Upstream suite",
              "Parity evidence", "Known gaps")
)


def build_text(legacy_rule, bazel_rule):
    targets = {
        "legacy_build": legacy_rule,
        "legacy_binary": "sh_binary",
        "legacy_test": "sh_test",
        "bazel_build": bazel_rule,
        "bazel_binary": "alias_to_bazel",
        "bazel_test": "sh_test",
        "parity_test": "parity_test",
        "upstream_inventory_test": "upstream_inventory_test",
    }
    return "\n".join(
        '%s(\n    name = "%s",\n)' % (rule, name)
        for name, rule in targets.items()
    )


def errors_for(build):
    errors = []
    rct.check_port("probe", build, README_OK, "version sha256 license",
                   "missing UPSTREAM", errors)
    return errors


class CheckPortTest(unittest.TestCase):
    def test_good_port_passes(self):
        self.assertEqual(errors_for(build_text("legacy_make", "cc_binary")), [])

    def test_vacuous_bazel_build_rejected(self):
        errs = errors_for(build_text("legacy_make", "legacy_make"))
        self.assertTrue(any("bazel_build" in e and "legacy_make" in e
                            for e in errs), errs)

    def test_native_legacy_build_rejected(self):
        errs = errors_for(build_text("cc_binary", "cc_binary"))
        self.assertTrue(any("legacy_build" in e and "cc_binary" in e
                            for e in errs), errs)

    def test_manual_tagged_interface_target_rejected(self):
        build = build_text("legacy_make", "cc_binary").replace(
            'parity_test(\n    name = "parity_test",\n)',
            'parity_test(\n    name = "parity_test",\n'
            '    tags = ["manual"],\n)')
        errs = errors_for(build)
        self.assertTrue(any("manual" in e and "parity_test" in e
                            for e in errs), errs)

    def test_missing_self_checks_rejected(self):
        # A BUILD without upstream_inventory_test (the bzip2 haiku probe
        # also skipped the self-checks entirely).
        build = build_text("legacy_make", "cc_binary").replace(
            'upstream_inventory_test(\n    name = "upstream_inventory_test",\n)', "")
        errs = errors_for(build)
        self.assertTrue(any("upstream_inventory_test" in e for e in errs), errs)


if __name__ == "__main__":
    unittest.main()
