#!/usr/bin/env python3
"""Unit tests for claude_supervisor.py's Complexity -> effort mapping
(P0-16). Scoped to the mapping function per the task's Testing Requirements
- no supervisor loop/process tests here. Run with `python3 -m unittest
test_claude_supervisor` or `pytest test_claude_supervisor.py`."""

import unittest

from claude_supervisor import (
    effort_for_task,
    is_security_floor_package,
    parse_task_header,
)


def header(complexity=None, primary_package=None):
    parts = ["**Epic:** E1"]
    if primary_package is not None:
        parts.append(f"**Primary package:** {primary_package}")
    if complexity is not None:
        parts.append(f"**Complexity:** {complexity}")
    parts.append("**Priority:** Medium")
    return " · ".join(parts)


class ParseTaskHeaderTests(unittest.TestCase):
    def test_extracts_complexity_and_primary_package(self):
        text = header(complexity="M", primary_package="`Packages/DocEngineHost`")
        complexity, primary_package = parse_task_header(text)
        self.assertEqual(complexity, "M")
        self.assertEqual(primary_package, "`Packages/DocEngineHost`")

    def test_multi_value_primary_package_field_captured_whole(self):
        text = header(
            complexity="L",
            primary_package="`Packages/InferenceHost` + `Services/InferenceService` `[INTEGRATION]`",
        )
        complexity, primary_package = parse_task_header(text)
        self.assertEqual(complexity, "L")
        self.assertEqual(
            primary_package,
            "`Packages/InferenceHost` + `Services/InferenceService` `[INTEGRATION]`",
        )

    def test_missing_complexity_field_is_none(self):
        text = header(primary_package="`Packages/DocumentSession`")
        complexity, _ = parse_task_header(text)
        self.assertIsNone(complexity)

    def test_malformed_complexity_value_is_none(self):
        text = header(complexity="XL", primary_package="`Packages/DocumentSession`")
        complexity, _ = parse_task_header(text)
        self.assertIsNone(complexity)

    def test_missing_primary_package_field_is_none(self):
        text = header(complexity="S")
        _, primary_package = parse_task_header(text)
        self.assertIsNone(primary_package)

    def test_no_header_at_all_returns_none_none(self):
        complexity, primary_package = parse_task_header("no header here")
        self.assertIsNone(complexity)
        self.assertIsNone(primary_package)


class SecurityFloorPackageTests(unittest.TestCase):
    def test_api_package_matches(self):
        self.assertTrue(is_security_floor_package("`Packages/VaultAPI`"))

    def test_policykit_matches(self):
        self.assertTrue(is_security_floor_package("`Packages/PolicyKit`"))

    def test_literal_xpc_mention_matches(self):
        self.assertTrue(is_security_floor_package("Vault.xpc"))

    def test_vault_service_target_matches(self):
        self.assertTrue(is_security_floor_package("`Services/VaultService`"))

    def test_docengine_service_target_matches(self):
        self.assertTrue(is_security_floor_package("`Services/DocEngineService`"))

    def test_inference_service_target_matches(self):
        self.assertTrue(is_security_floor_package("`Services/InferenceService`"))

    def test_ordinary_package_does_not_match(self):
        self.assertFalse(is_security_floor_package("`Packages/DocumentSession`"))

    def test_none_does_not_match(self):
        self.assertFalse(is_security_floor_package(None))


class EffortForTaskTests(unittest.TestCase):
    def test_small_complexity_maps_to_low(self):
        self.assertEqual(effort_for_task("S", "`Packages/DocumentSession`"), "low")

    def test_medium_complexity_maps_to_medium(self):
        self.assertEqual(effort_for_task("M", "`Packages/DocumentSession`"), "medium")

    def test_large_complexity_maps_to_high(self):
        self.assertEqual(effort_for_task("L", "`Packages/DocumentSession`"), "high")

    def test_missing_complexity_falls_back_to_medium(self):
        self.assertEqual(effort_for_task(None, "`Packages/DocumentSession`"), "medium")

    def test_small_complexity_on_api_package_floored_to_medium(self):
        self.assertEqual(effort_for_task("S", "`Packages/VaultAPI`"), "medium")

    def test_small_complexity_on_policykit_floored_to_medium(self):
        self.assertEqual(effort_for_task("S", "`Packages/PolicyKit`"), "medium")

    def test_small_complexity_on_xpc_service_floored_to_medium(self):
        self.assertEqual(effort_for_task("S", "`Services/VaultService`"), "medium")

    def test_large_complexity_on_api_package_stays_high(self):
        # The floor only ever raises `low`; it never lowers a higher effort.
        self.assertEqual(effort_for_task("L", "`Packages/VaultAPI`"), "high")

    def test_missing_complexity_and_missing_package_falls_back_to_medium(self):
        self.assertEqual(effort_for_task(None, None), "medium")


if __name__ == "__main__":
    unittest.main()
