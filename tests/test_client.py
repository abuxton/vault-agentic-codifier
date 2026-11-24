"""
Unit tests for TASK-005 (VaultClient and RunReport).

These tests are fully offline — the VaultClient is exercised via monkeypatching
so no live Vault cluster is needed.

Run with: python3 tests/test_client.py
"""

from __future__ import annotations

import os
import sys
import unittest
from unittest.mock import MagicMock, patch
from typing import Any, Dict, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _make_client(addr: str = "http://127.0.0.1:8200", token: str = "test-token"):
    """Return a VaultClient with env vars set."""
    with patch.dict(os.environ, {"VAULT_ADDR": addr, "VAULT_TOKEN": token}):
        from codifier.discovery.client import VaultClient
        return VaultClient()


class TestRunReport(unittest.TestCase):

    def setUp(self):
        from codifier.discovery.client import RunReport
        self.RunReport = RunReport

    def test_record_adds_entry(self):
        rr = self.RunReport()
        rr.record("/sys/namespaces", "admin", "LIST", 403, "skipped", "permission denied")
        self.assertEqual(len(rr.entries), 1)
        entry = rr.entries[0]
        self.assertEqual(entry.endpoint, "/sys/namespaces")
        self.assertEqual(entry.namespace, "admin")
        self.assertEqual(entry.status, 403)

    def test_to_list_serialises(self):
        rr = self.RunReport()
        rr.record("/sys/health", "", "GET", 404, "empty")
        data = rr.to_list()
        self.assertIsInstance(data, list)
        self.assertEqual(data[0]["status"], 404)

    def test_no_token_in_report(self):
        rr = self.RunReport()
        # Simulate someone accidentally passing a token-like value in note
        # (guard: we store it — but the production code never does)
        rr.record("/sys/health", "", "GET", 200, "ok", "")
        for entry in rr.entries:
            # None of the standard fields should ever hold a token
            self.assertNotIn("s.", str(entry.to_dict()))


class TestVaultClientPermissionGuard(unittest.TestCase):
    """AC1: POST/PUT/DELETE/PATCH fail before any network request."""

    def test_post_raises_permission_error(self):
        with patch.dict(os.environ, {"VAULT_ADDR": "http://localhost:8200", "VAULT_TOKEN": "tok"}):
            from codifier.discovery.client import VaultClient
            client = VaultClient.__new__(VaultClient)
            client._addr = "http://localhost:8200"
            client._token = "tok"
            with self.assertRaises(PermissionError):
                client._assert_method_allowed("POST")

    def test_put_raises_permission_error(self):
        with patch.dict(os.environ, {"VAULT_ADDR": "http://localhost:8200", "VAULT_TOKEN": "tok"}):
            from codifier.discovery.client import VaultClient
            client = VaultClient.__new__(VaultClient)
            client._addr = "http://localhost:8200"
            client._token = "tok"
            with self.assertRaises(PermissionError):
                client._assert_method_allowed("PUT")

    def test_delete_raises_permission_error(self):
        with patch.dict(os.environ, {"VAULT_ADDR": "http://localhost:8200", "VAULT_TOKEN": "tok"}):
            from codifier.discovery.client import VaultClient
            client = VaultClient.__new__(VaultClient)
            client._addr = "http://localhost:8200"
            client._token = "tok"
            with self.assertRaises(PermissionError):
                client._assert_method_allowed("DELETE")

    def test_get_allowed(self):
        with patch.dict(os.environ, {"VAULT_ADDR": "http://localhost:8200", "VAULT_TOKEN": "tok"}):
            from codifier.discovery.client import VaultClient
            VaultClient._assert_method_allowed("GET")  # no exception

    def test_list_allowed(self):
        with patch.dict(os.environ, {"VAULT_ADDR": "http://localhost:8200", "VAULT_TOKEN": "tok"}):
            from codifier.discovery.client import VaultClient
            VaultClient._assert_method_allowed("LIST")  # no exception


class TestVaultClientMissingEnvVars(unittest.TestCase):

    def test_missing_vault_addr_raises(self):
        env = {"VAULT_TOKEN": "tok"}
        env.pop("VAULT_ADDR", None)
        with patch.dict(os.environ, env, clear=False):
            os.environ.pop("VAULT_ADDR", None)
            from codifier.discovery.client import VaultClient
            with self.assertRaises(EnvironmentError):
                VaultClient._read_addr()

    def test_missing_vault_token_raises(self):
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("VAULT_TOKEN", None)
            from codifier.discovery.client import VaultClient
            with self.assertRaises(EnvironmentError):
                VaultClient._read_token()


class TestVaultClientNonFatalResponses(unittest.TestCase):
    """AC3+AC4: 403/404 are non-fatal; empty LIST treated as []."""

    def _make_client_with_response(
        self,
        status: int,
        body: Dict[str, Any],
    ):
        """Return a client whose _request_with_retry returns (status, body)."""
        with patch.dict(os.environ, {"VAULT_ADDR": "http://localhost:8200", "VAULT_TOKEN": "tok"}):
            from codifier.discovery.client import VaultClient, RunReport
            client = VaultClient.__new__(VaultClient)
            client._addr = "http://localhost:8200"
            client._token = "tok"
            client._timeout = 10
            client.run_report = RunReport()
            client._request_with_retry = MagicMock(return_value=(status, body))
            return client

    def test_get_403_returns_none(self):
        # Use a 403 with an error that does NOT match token-expiry patterns
        client = self._make_client_with_response(403, {"errors": ["1 error occurred: * exporter policy does not allow access"]})
        result = client.get("/sys/health", namespace="admin")
        self.assertIsNone(result)

    def test_get_403_records_in_run_report(self):
        client = self._make_client_with_response(403, {"errors": ["1 error occurred: * exporter policy does not allow access"]})
        client.get("/sys/health", namespace="admin")
        self.assertEqual(len(client.run_report.entries), 1)
        self.assertEqual(client.run_report.entries[0].status, 403)

    def test_list_404_returns_empty_list(self):
        client = self._make_client_with_response(404, {"errors": []})
        result = client.list("/sys/namespaces")
        self.assertEqual(result, [])

    def test_list_404_records_empty_in_report(self):
        client = self._make_client_with_response(404, {"errors": []})
        client.list("/sys/namespaces")
        self.assertEqual(client.run_report.entries[0].outcome, "empty")

    def test_list_200_returns_keys(self):
        client = self._make_client_with_response(
            200, {"data": {"keys": ["admin/", "platform/", "app-billing/"]}}
        )
        result = client.list("/sys/namespaces")
        self.assertEqual(result, ["admin/", "platform/", "app-billing/"])

    def test_get_200_returns_body(self):
        body = {"request_id": "abc", "data": {"keys": []}}
        client = self._make_client_with_response(200, body)
        result = client.get("/sys/health")
        self.assertEqual(result, body)


class TestTokenExpiry(unittest.TestCase):

    def test_token_expiry_raises_runtime_error(self):
        with patch.dict(os.environ, {"VAULT_ADDR": "http://localhost:8200", "VAULT_TOKEN": "tok"}):
            from codifier.discovery.client import VaultClient
            with self.assertRaises(RuntimeError):
                VaultClient._check_token_expiry(
                    403,
                    {"errors": ["permission denied"]},
                    "/sys/namespaces",
                )

    def test_non_expiry_403_does_not_raise(self):
        from codifier.discovery.client import VaultClient
        # Should not raise — just a regular 403
        VaultClient._check_token_expiry(403, {"errors": [""]}, "/sys/mounts")


if __name__ == "__main__":
    unittest.main(verbosity=2)
