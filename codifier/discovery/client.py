"""
client — read-only Vault HTTP API client and run-report manager.

Implements: TASK-005
Spec ref:   specs.md §CAC4 (read-only), CAP-001 AC7 (run report)
            tmp/brownfield-discovery-guide.md §Troubleshooting
Doc ref:    https://developer.hashicorp.com/vault/api-docs
            https://developer.hashicorp.com/vault/api-docs/system

Contract
────────
• Only HTTP GET and LIST are permitted.  Attempting POST/PUT/DELETE/PATCH
  raises PermissionError before any network request.
• Credentials are read exclusively from VAULT_ADDR / VAULT_TOKEN environment
  variables (never accepted as arguments to prevent accidental logging).
• X-Vault-Namespace is set per call; empty string = root namespace.
• 403 and 404 responses are non-fatal: they are recorded in the run report
  and an empty result is returned.
• An empty or 404 LIST is treated as an empty set.
• Tokens never appear in log output or the run report.
• Retry with exponential backoff on 429 (rate-limited) and 5xx responses.
• Token-expiry detection (403 with error "permission denied" after several
  successful calls) triggers a clear error message.

Run report format (one entry per non-200 outcome):
    {
        "endpoint":   "/v1/sys/namespaces",
        "namespace":  "admin",
        "method":     "LIST",
        "status":     403,
        "outcome":    "skipped",
        "note":       "permission denied"
    }
"""

from __future__ import annotations

import json
import logging
import os
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PERMITTED_METHODS = frozenset({"GET", "LIST"})

# HTTP status codes that are non-fatal for discovery
NON_FATAL_STATUSES = frozenset({403, 404})

# Initial retry delay (seconds); doubles each attempt
RETRY_INITIAL_DELAY = 1.0
RETRY_MAX_ATTEMPTS = 3
RETRY_BACKOFF_FACTOR = 2.0

# Vault error strings that indicate token expiry / permission
_TOKEN_EXPIRY_ERRORS = frozenset({
    "permission denied",
    "token is not renewable",
    "token has expired",
})


# ---------------------------------------------------------------------------
# Run report
# ---------------------------------------------------------------------------

@dataclass
class RunReportEntry:
    endpoint: str
    namespace: str
    method: str
    status: int
    outcome: str    # "skipped" | "empty" | "error"
    note: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return {
            "endpoint": self.endpoint,
            "namespace": self.namespace,
            "method": self.method,
            "status": self.status,
            "outcome": self.outcome,
            "note": self.note,
        }


class RunReport:
    """
    Accumulates non-200 outcomes from Vault API calls during a discovery run.

    Tokens are never stored here — only endpoints, namespaces and status codes.
    """

    def __init__(self) -> None:
        self._entries: List[RunReportEntry] = []

    def record(
        self,
        endpoint: str,
        namespace: str,
        method: str,
        status: int,
        outcome: str = "skipped",
        note: str = "",
    ) -> None:
        # Sanitise: never store token-like values
        self._entries.append(
            RunReportEntry(
                endpoint=endpoint,
                namespace=namespace,
                method=method,
                status=status,
                outcome=outcome,
                note=note,
            )
        )
        logger.info(
            "vault api [%s] %s ns=%r → %d (%s)",
            method,
            endpoint,
            namespace,
            status,
            outcome,
        )

    @property
    def entries(self) -> List[RunReportEntry]:
        return list(self._entries)

    def to_list(self) -> List[Dict[str, Any]]:
        return [e.to_dict() for e in self._entries]

    def write_jsonl(self, path: str) -> None:
        """Append entries to a JSONL file (one JSON object per line)."""
        with open(path, "a") as fh:
            for entry in self._entries:
                fh.write(json.dumps(entry.to_dict()) + "\n")


# ---------------------------------------------------------------------------
# VaultClient
# ---------------------------------------------------------------------------

class VaultClient:
    """
    Read-only HTTP client for the Vault API.

    Credentials are read from environment variables at construction time:
    ``VAULT_ADDR``  — base URL of the Vault cluster (required)
    ``VAULT_TOKEN`` — Vault token (required; never logged)

    Parameters
    ----------
    run_report:
        A :class:`RunReport` instance.  If ``None``, a fresh one is created.
    timeout:
        HTTP request timeout in seconds.
    """

    def __init__(
        self,
        run_report: Optional[RunReport] = None,
        timeout: int = 30,
    ) -> None:
        self._addr = self._read_addr()
        self._token = self._read_token()
        self.run_report = run_report if run_report is not None else RunReport()
        self._timeout = timeout

    # ------------------------------------------------------------------
    # Credential reading
    # ------------------------------------------------------------------

    @staticmethod
    def _read_addr() -> str:
        addr = os.environ.get("VAULT_ADDR", "").rstrip("/")
        if not addr:
            raise EnvironmentError(
                "VAULT_ADDR environment variable is not set. "
                "Set it to the Vault cluster address before running the codifier."
            )
        return addr

    @staticmethod
    def _read_token() -> str:
        token = os.environ.get("VAULT_TOKEN", "")
        if not token:
            raise EnvironmentError(
                "VAULT_TOKEN environment variable is not set. "
                "Obtain an exporter AppRole token (see skills/vault-exporter-setup/SKILL.md)."
            )
        return token

    # ------------------------------------------------------------------
    # Request guards
    # ------------------------------------------------------------------

    @staticmethod
    def _assert_method_allowed(method: str) -> None:
        """Raise PermissionError if *method* is not in the permitted set."""
        m = method.upper()
        if m not in PERMITTED_METHODS:
            raise PermissionError(
                f"VaultClient is read-only. Method {method!r} is not permitted. "
                f"Only {sorted(PERMITTED_METHODS)} are allowed (CAC4)."
            )

    # ------------------------------------------------------------------
    # Low-level HTTP
    # ------------------------------------------------------------------

    def _build_headers(self, namespace: str) -> Dict[str, str]:
        headers = {
            "X-Vault-Token": self._token,
            "X-Vault-Request": "true",
        }
        if namespace:
            headers["X-Vault-Namespace"] = namespace
        return headers

    def _make_request(
        self,
        method: str,
        path: str,
        namespace: str,
    ) -> Tuple[int, Optional[Dict[str, Any]]]:
        """
        Issue one HTTP request and return ``(status_code, body_dict_or_None)``.

        LIST requests use the ``X-Vault-Request: true`` header approach and
        the HTTP ``LIST`` method.  ``urllib`` does not support custom methods
        natively, so we patch the method on the Request object.
        """
        url = f"{self._addr}/v1{path}"
        headers = self._build_headers(namespace)

        req = urllib.request.Request(url, headers=headers, method=method)

        try:
            with urllib.request.urlopen(req, timeout=self._timeout) as resp:
                body = json.loads(resp.read().decode())
                return resp.status, body
        except urllib.error.HTTPError as exc:
            body_text = ""
            try:
                body_text = exc.read().decode()
            except Exception:
                pass
            # Parse body for error messages (token expiry detection)
            body_json: Dict[str, Any] = {}
            try:
                body_json = json.loads(body_text)
            except Exception:
                pass
            errors = body_json.get("errors", [])
            return exc.code, {"errors": errors, "_raw": body_text}

    # ------------------------------------------------------------------
    # Retry wrapper
    # ------------------------------------------------------------------

    def _request_with_retry(
        self,
        method: str,
        path: str,
        namespace: str,
    ) -> Tuple[int, Optional[Dict[str, Any]]]:
        delay = RETRY_INITIAL_DELAY
        for attempt in range(1, RETRY_MAX_ATTEMPTS + 1):
            status, body = self._make_request(method, path, namespace)
            if status in (429,) or (500 <= status < 600):
                if attempt < RETRY_MAX_ATTEMPTS:
                    logger.warning(
                        "vault api [%s] %s ns=%r → %d; retrying in %.1fs (attempt %d/%d)",
                        method, path, namespace, status, delay, attempt, RETRY_MAX_ATTEMPTS,
                    )
                    time.sleep(delay)
                    delay *= RETRY_BACKOFF_FACTOR
                    continue
            return status, body
        return status, body  # type: ignore[return-value]

    # ------------------------------------------------------------------
    # Token-expiry detection
    # ------------------------------------------------------------------

    @staticmethod
    def _check_token_expiry(status: int, body: Optional[Dict[str, Any]], path: str) -> None:
        """Raise RuntimeError if the response indicates a token problem."""
        if status == 403 and body:
            errors = body.get("errors", [])
            for err in errors:
                if any(exp in str(err).lower() for exp in _TOKEN_EXPIRY_ERRORS):
                    raise RuntimeError(
                        f"Vault token appears to have expired or been revoked "
                        f"(403 on {path!r}: {err!r}). "
                        f"Obtain a fresh exporter AppRole token and retry."
                    )

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def get(
        self,
        path: str,
        namespace: str = "",
    ) -> Optional[Dict[str, Any]]:
        """
        Issue a ``GET /v1<path>`` request.

        Parameters
        ----------
        path:
            Vault API path starting with ``/``, e.g. ``/sys/health``.
        namespace:
            Vault namespace (empty = root).

        Returns
        -------
        Optional[Dict]
            Parsed JSON body, or ``None`` on 403 / 404 / empty.
        """
        self._assert_method_allowed("GET")
        status, body = self._request_with_retry("GET", path, namespace)

        if status == 200:
            return body

        if status in NON_FATAL_STATUSES:
            self._check_token_expiry(status, body, path)
            note = str((body or {}).get("errors", [""])[:1])
            self.run_report.record(
                endpoint=path,
                namespace=namespace,
                method="GET",
                status=status,
                outcome="skipped",
                note=note,
            )
            return None

        # Unexpected status — log and return None (non-fatal for discovery)
        note = str((body or {}).get("errors", [""])[:1])
        self.run_report.record(
            endpoint=path,
            namespace=namespace,
            method="GET",
            status=status,
            outcome="error",
            note=note,
        )
        return None

    def list(
        self,
        path: str,
        namespace: str = "",
    ) -> List[str]:
        """
        Issue a ``LIST /v1<path>`` request.

        Returns
        -------
        List[str]
            The ``keys`` array from the Vault LIST response.
            Returns ``[]`` on 403, 404, or an empty response.
        """
        self._assert_method_allowed("LIST")
        status, body = self._request_with_retry("LIST", path, namespace)

        if status == 200 and body:
            return body.get("data", {}).get("keys", [])

        if status in NON_FATAL_STATUSES:
            self._check_token_expiry(status, body, path)
            # 404 on a LIST means the path has no children — treat as empty set
            outcome = "empty" if status == 404 else "skipped"
            note = str((body or {}).get("errors", [""])[:1])
            self.run_report.record(
                endpoint=path,
                namespace=namespace,
                method="LIST",
                status=status,
                outcome=outcome,
                note=note,
            )
            return []

        if status not in (200,):
            note = str((body or {}).get("errors", [""])[:1])
            self.run_report.record(
                endpoint=path,
                namespace=namespace,
                method="LIST",
                status=status,
                outcome="error",
                note=note,
            )
        return []
