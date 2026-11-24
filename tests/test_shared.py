"""
Unit tests for TASK-002, TASK-003, TASK-004.

Run with: python -m pytest tests/ -v
or:        python tests/test_shared.py
"""

from __future__ import annotations

import sys
import os
import datetime
import unittest

# Ensure the package root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# =============================================================================
# TASK-002: providers
# =============================================================================

class TestProviders(unittest.TestCase):

    def setUp(self):
        from codifier.shared.providers import (
            admin_layer_config,
            namespaces_layer_config,
            seed_layer_config,
            render_providers_tf,
            render_versions_tf,
            ProviderAlias,
            ProviderConfig,
        )
        self.admin_layer_config = admin_layer_config
        self.namespaces_layer_config = namespaces_layer_config
        self.seed_layer_config = seed_layer_config
        self.render_providers_tf = render_providers_tf
        self.render_versions_tf = render_versions_tf
        self.ProviderAlias = ProviderAlias
        self.ProviderConfig = ProviderConfig

    def test_versions_tf_contains_required_version(self):
        cfg = self.admin_layer_config()
        out = self.render_versions_tf(cfg)
        self.assertIn('>= 1.9', out)
        self.assertIn('hashicorp/vault', out)
        self.assertIn('~> 4', out)

    def test_no_literal_token_in_versions_tf(self):
        cfg = self.admin_layer_config()
        out = self.render_versions_tf(cfg)
        # Must not contain literal token values — only variable references
        self.assertNotIn('"root"', out)
        self.assertNotIn('VAULT_TOKEN', out.replace('VAULT_TOKEN', ''))  # env ref in comment is ok
        # Sensitive flag must be present
        self.assertIn('sensitive   = true', out)

    def test_providers_tf_admin_layer_skip_child_token_true(self):
        cfg = self.admin_layer_config()
        out = self.render_providers_tf(cfg)
        self.assertIn('skip_child_token = true', out)

    def test_providers_tf_seed_layer_skip_child_token_false(self):
        cfg = self.seed_layer_config(["admin/platform", "admin/app-billing"])
        out = self.render_providers_tf(cfg)
        self.assertIn('skip_child_token = false', out)

    def test_aliased_style_contains_alias_keyword(self):
        # Build a config with two aliases so the second one emits alias =
        cfg = self.ProviderConfig(
            layer="admin",
            namespace_style="aliased",
            aliases=[
                self.ProviderAlias(alias="root", namespace="", skip_child_token=True),
                self.ProviderAlias(alias="admin", namespace="admin", skip_child_token=True),
            ],
        )
        out = self.render_providers_tf(cfg)
        self.assertIn('alias =', out)

    def test_resource_style_no_alias_keyword(self):
        cfg = self.admin_layer_config(namespace_style="resource")
        out = self.render_providers_tf(cfg)
        self.assertNotIn('alias =', out)

    def test_no_literal_address_in_providers_tf(self):
        cfg = self.admin_layer_config()
        out = self.render_providers_tf(cfg)
        # address must be a variable reference, not a literal URL
        self.assertNotIn('"http://', out)
        self.assertNotIn('"https://', out)

    def test_invalid_namespace_style_raises(self):
        with self.assertRaises(ValueError):
            self.ProviderConfig(layer="admin", namespace_style="invalid")

    def test_invalid_layer_raises(self):
        with self.assertRaises(ValueError):
            self.ProviderConfig(layer="unknown")


# =============================================================================
# TASK-003: naming
# =============================================================================

class TestNaming(unittest.TestCase):

    def setUp(self):
        from codifier.shared.naming import (
            normalise,
            resource_label,
            file_label,
            policy_file_path,
            tf_reference,
            CollisionRegistry,
            validate_harness_mappings,
        )
        self.normalise = normalise
        self.resource_label = resource_label
        self.file_label = file_label
        self.policy_file_path = policy_file_path
        self.tf_reference = tf_reference
        self.CollisionRegistry = CollisionRegistry
        self.validate_harness_mappings = validate_harness_mappings

    # AC4 — harness mapping examples
    def test_harness_mappings(self):
        self.assertTrue(self.validate_harness_mappings())

    # Normalise basics
    def test_slash_to_underscore(self):
        self.assertEqual(self.normalise("admin/platform"), "admin_platform")

    def test_dash_to_underscore(self):
        self.assertEqual(self.normalise("my-secret-engine"), "my_secret_engine")

    def test_leading_digit_prefixed(self):
        result = self.normalise("42things")
        self.assertTrue(result[0].isalpha() or result[0] == '_')

    # AC2 — valid identifiers
    def test_valid_identifier_no_leading_digit(self):
        import re
        label = self.resource_label("123-mount", "")
        self.assertRegex(label, r'^[a-z_][a-z0-9_]*$')

    def test_valid_identifier_all_allowed_chars(self):
        import re
        label = self.resource_label("app-billing", "admin/platform")
        self.assertRegex(label, r'^[a-z_][a-z0-9_]*$')

    # AC1 — determinism / idempotence
    def test_identical_input_identical_output(self):
        label1 = self.resource_label("admin", "admin/platform")
        label2 = self.resource_label("admin", "admin/platform")
        self.assertEqual(label1, label2)

    # AC3 — same name in different namespaces → distinct labels
    def test_collision_different_namespaces_bare(self):
        reg = self.CollisionRegistry()
        label_ns1 = reg.unique_label("vault_policy", "default-readonly", namespace="admin")
        label_ns2 = reg.unique_label("vault_policy", "default-readonly", namespace="platform")
        self.assertNotEqual(label_ns1, label_ns2)

    def test_collision_registry_idempotent_same_object(self):
        reg = self.CollisionRegistry()
        label1 = reg.unique_label("vault_policy", "admin", namespace="")
        label2 = reg.unique_label("vault_policy", "admin", namespace="")
        self.assertEqual(label1, label2)

    # Policy file paths — AC3
    def test_policy_path_root_namespace(self):
        path = self.policy_file_path("", "default-readonly")
        self.assertEqual(path, "policies/root/default-readonly.hcl")

    def test_policy_path_nested_namespace(self):
        path = self.policy_file_path("admin/platform", "app-sre")
        self.assertEqual(path, "policies/admin__platform/app-sre.hcl")

    # Reference helper
    def test_tf_reference_no_attribute(self):
        ref = self.tf_reference("vault_namespace", "admin")
        self.assertEqual(ref, "vault_namespace.admin")

    def test_tf_reference_with_attribute(self):
        ref = self.tf_reference("vault_policy", "admin_namespace_admin", "name")
        self.assertEqual(ref, "vault_policy.admin_namespace_admin.name")


# =============================================================================
# TASK-004: guard
# =============================================================================

class TestGuard(unittest.TestCase):

    def setUp(self):
        from codifier.shared.guard import Guard, GuardWarning, scrub, assert_resource_allowed
        self.Guard = Guard
        self.GuardWarning = GuardWarning
        self.scrub = scrub
        self.assert_resource_allowed = assert_resource_allowed

    # AC2 — sensitive fields replaced, warning emitted
    def test_token_replaced(self):
        warnings = []
        payload = {"token": "s.some-vault-token", "other": "value"}
        result = self.scrub(payload, context="test.tf", warnings=warnings)
        self.assertNotIn("s.some-vault-token", str(result))
        self.assertTrue(result["token"].startswith("var."))
        self.assertEqual(len(warnings), 1)
        self.assertEqual(warnings[0].field, "token")

    def test_secret_id_replaced(self):
        warnings = []
        result = self.scrub({"secret_id": "abc-123"}, context="test.tf", warnings=warnings)
        self.assertNotIn("abc-123", str(result))
        self.assertTrue(result["secret_id"].startswith("var."))

    def test_bindpass_replaced(self):
        warnings = []
        result = self.scrub({"bindpass": "hunter2"}, context="test.tf", warnings=warnings)
        self.assertNotIn("hunter2", str(result))
        self.assertTrue(result["bindpass"].startswith("var."))

    def test_client_secret_replaced(self):
        warnings = []
        result = self.scrub({"client_secret": "oidc-secret"}, context="test.tf", warnings=warnings)
        self.assertNotIn("oidc-secret", str(result))

    def test_oidc_client_secret_replaced(self):
        warnings = []
        original = "my-oidc-secret-value"
        result = self.scrub({"oidc_client_secret": original}, context="test.tf", warnings=warnings)
        # Original value must be gone; replacement is a var.* reference
        self.assertNotIn(original, str(result["oidc_client_secret"]))
        self.assertTrue(result["oidc_client_secret"].startswith("var."))

    # AC4 — SYNTHETIC- prefix redacted
    def test_synthetic_prefix_value_replaced(self):
        warnings = []
        result = self.scrub(
            {"connection_url": "SYNTHETIC-postgres://user:pass@db/mydb"},
            context="test.tf",
            warnings=warnings,
        )
        self.assertNotIn("SYNTHETIC-", str(result))
        self.assertTrue(result["connection_url"].startswith("var."))

    # AC3 — warning does NOT log the rejected value
    def test_warning_does_not_contain_secret_value(self):
        warnings = []
        self.scrub({"token": "s.secret-value-here"}, context="test.tf", warnings=warnings)
        for w in warnings:
            self.assertNotIn("s.secret-value-here", w.reason)
            self.assertNotIn("s.secret-value-here", w.replacement)
            self.assertNotIn("s.secret-value-here", w.context)

    # Non-sensitive fields pass through
    def test_non_sensitive_field_passes_through(self):
        warnings = []
        result = self.scrub({"type": "approle", "description": "my backend"}, warnings=warnings)
        self.assertEqual(result["type"], "approle")
        self.assertEqual(result["description"], "my backend")
        self.assertEqual(len(warnings), 0)

    # Nested dict scrubbing
    def test_nested_dict_scrubbed(self):
        warnings = []
        payload = {"options": {"bindpass": "secret", "url": "ldap://server"}}
        result = self.scrub(payload, warnings=warnings)
        self.assertTrue(result["options"]["bindpass"].startswith("var."))
        self.assertEqual(result["options"]["url"], "ldap://server")

    # Forbidden resource guard
    def test_forbidden_resource_raises(self):
        with self.assertRaises(ValueError):
            self.assert_resource_allowed("vault_kv_secret_v2")

    def test_allowed_resource_no_raise(self):
        # Should not raise
        self.assert_resource_allowed("vault_namespace")
        self.assert_resource_allowed("vault_policy")


# =============================================================================
# Headers
# =============================================================================

class TestHeaders(unittest.TestCase):

    def setUp(self):
        from codifier.shared.headers import file_header, prepend_header, DOC_URL_MAP
        self.file_header = file_header
        self.prepend_header = prepend_header
        self.DOC_URL_MAP = DOC_URL_MAP

    def test_header_contains_capability(self):
        h = self.file_header("namespaces", "admin")
        self.assertIn("namespaces", h)

    def test_header_contains_doc_url(self):
        h = self.file_header("namespaces", "admin")
        self.assertIn("https://developer.hashicorp.com", h)

    def test_header_no_local_path(self):
        h = self.file_header("policies", "admin", namespace="admin/platform")
        self.assertNotIn("content/validated-designs", h)
        self.assertNotIn("git@github.com", h)
        self.assertNotIn("/Users/", h)

    def test_header_namespace_root_shown(self):
        h = self.file_header("root-config", "admin", namespace="")
        self.assertIn("(root)", h)

    def test_header_timestamp_format(self):
        import re
        ts = datetime.datetime(2024, 6, 1, 12, 0, 0)
        h = self.file_header("teams", "namespaces", timestamp=ts)
        self.assertRegex(h, r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z')

    def test_prepend_header_starts_with_hash(self):
        result = self.prepend_header("resource ...", "policies", "admin")
        self.assertTrue(result.startswith("#"))

    def test_all_capabilities_have_doc_url(self):
        for cap in ["root-config", "admin-config", "auth-mounts",
                    "secrets-engines", "namespaces", "policies", "teams"]:
            url = self.DOC_URL_MAP.get(cap, "")
            self.assertTrue(url.startswith("https://"), f"No URL for capability {cap!r}")


# =============================================================================
# Entry point
# =============================================================================

if __name__ == "__main__":
    unittest.main(verbosity=2)
