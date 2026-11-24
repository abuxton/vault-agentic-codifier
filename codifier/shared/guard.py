"""
guard — secret-scrubbing and sensitive-field guard.

Implements: TASK-004b
Spec ref:   specs.md §CAC3 (no secrets on disk), CAP-003 AC5, CAP-004 AC3
Doc ref:    https://developer.hashicorp.com/vault/docs

The guard sits between Vault API responses and the codification generators.
Its contract:

  1. It NEVER logs the rejected value itself — only the field name and file.
  2. Any field in SENSITIVE_FIELDS (from constants) is replaced with a
     Terraform sensitive variable reference:  ``var.<field_name>``
     and a warning entry is appended to the run-report list.
  3. Fields whose name starts with a SENSITIVE_FIELD_PREFIX are treated
     identically.
  4. String values that start with SYNTHETIC_PREFIX are also redacted (belt
     and suspenders — synthetic data must never reach generated output either).
  5. The guard operates on arbitrary dict payloads (Vault API JSON objects)
     and returns a sanitised copy.

Usage::

    from codifier.shared.guard import Guard, GuardWarning

    warnings: list[GuardWarning] = []
    guard = Guard(context="admin/auth_approle.tf")
    clean = guard.scrub(vault_payload, warnings=warnings)
"""

from __future__ import annotations

import copy
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from codifier.shared.constants import (
    SENSITIVE_FIELDS,
    SENSITIVE_FIELD_PREFIXES,
    SYNTHETIC_PREFIX,
)

# ---------------------------------------------------------------------------
# Forbidden resource guard
# ---------------------------------------------------------------------------
from codifier.shared.constants import FORBIDDEN_RESOURCES


def assert_resource_allowed(resource_type: str) -> None:
    """
    Raise ValueError if *resource_type* is in the FORBIDDEN_RESOURCES set.

    Called by every generator before emitting a resource block.
    """
    if resource_type in FORBIDDEN_RESOURCES:
        reason = FORBIDDEN_RESOURCES[resource_type]
        raise ValueError(
            f"Forbidden resource type {resource_type!r}: {reason}"
        )


# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------

@dataclass
class GuardWarning:
    """
    A single warning emitted by the guard.

    Attributes
    ----------
    context:
        The output file path that was being written (never the token or value).
    field:
        The name of the field that was redacted.
    reason:
        Human-readable reason for redaction (``"sensitive_field"``,
        ``"sensitive_prefix"``, or ``"synthetic_placeholder"``).
    replacement:
        The Terraform expression that replaced the original value
        (e.g. ``"var.bindpass"``).
    """
    context: str
    field: str
    reason: str
    replacement: str

    def to_dict(self) -> Dict[str, str]:
        return {
            "context": self.context,
            "field": self.field,
            "reason": self.reason,
            "replacement": self.replacement,
        }


# ---------------------------------------------------------------------------
# Guard implementation
# ---------------------------------------------------------------------------

class Guard:
    """
    Scrubs sensitive values from Vault API payloads before they reach disk.

    Parameters
    ----------
    context:
        A descriptive label for the file being generated (used in warnings;
        never include token values here).
    """

    def __init__(self, context: str = "") -> None:
        self.context = context

    def _is_sensitive_field(self, key: str) -> bool:
        """Return True if *key* names a sensitive field."""
        lower = key.lower()
        if lower in SENSITIVE_FIELDS:
            return True
        for prefix in SENSITIVE_FIELD_PREFIXES:
            if lower.startswith(prefix):
                return True
        return False

    def _is_synthetic_value(self, value: Any) -> bool:
        """Return True if *value* is a string starting with SYNTHETIC_PREFIX."""
        return isinstance(value, str) and value.startswith(SYNTHETIC_PREFIX)

    def _replacement_expr(self, field: str) -> str:
        """
        Return the Terraform variable reference that replaces a sensitive value.

        The variable name is derived from the field name, normalised to a valid
        Terraform identifier (lowercase, underscores only).
        """
        import re
        var_name = re.sub(r"[^a-z0-9_]", "_", field.lower())
        return f"var.{var_name}"

    def scrub(
        self,
        payload: Any,
        warnings: Optional[List[GuardWarning]] = None,
    ) -> Any:
        """
        Return a deep copy of *payload* with all sensitive values replaced.

        Parameters
        ----------
        payload:
            A Vault API JSON object (dict, list, or scalar).  Dicts are
            recursively scrubbed.
        warnings:
            A mutable list to which :class:`GuardWarning` entries are appended.
            If ``None``, warnings are silently discarded.

        Returns
        -------
        Any
            A sanitised deep copy of *payload*.
        """
        if warnings is None:
            warnings = []

        return self._scrub_value(payload, warnings, field_name="")

    def _scrub_value(
        self,
        value: Any,
        warnings: List[GuardWarning],
        field_name: str,
    ) -> Any:
        """Recursive scrubbing dispatcher."""
        if isinstance(value, dict):
            return self._scrub_dict(value, warnings)
        if isinstance(value, list):
            return [self._scrub_value(v, warnings, field_name) for v in value]
        # Scalar: check for synthetic placeholder
        if field_name and self._is_synthetic_value(value):
            repl = self._replacement_expr(field_name)
            warnings.append(
                GuardWarning(
                    context=self.context,
                    field=field_name,
                    reason="synthetic_placeholder",
                    replacement=repl,
                )
            )
            return repl
        return value

    def _scrub_dict(
        self,
        d: Dict[str, Any],
        warnings: List[GuardWarning],
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {}
        for key, val in d.items():
            if self._is_sensitive_field(key):
                repl = self._replacement_expr(key)
                warnings.append(
                    GuardWarning(
                        context=self.context,
                        field=key,
                        reason=(
                            "sensitive_field"
                            if key.lower() in SENSITIVE_FIELDS
                            else "sensitive_prefix"
                        ),
                        replacement=repl,
                    )
                )
                result[key] = repl
            else:
                result[key] = self._scrub_value(val, warnings, key)
        return result


# ---------------------------------------------------------------------------
# Module-level convenience wrapper
# ---------------------------------------------------------------------------

def scrub(
    payload: Any,
    context: str = "",
    warnings: Optional[List[GuardWarning]] = None,
) -> Any:
    """
    Module-level shorthand: scrub *payload* and optionally collect warnings.

    Parameters
    ----------
    payload:
        Any Vault API response object.
    context:
        Output file path label (used in warnings; never a token value).
    warnings:
        Mutable list to collect :class:`GuardWarning` entries.

    Returns
    -------
    Any
        Sanitised copy of *payload*.
    """
    return Guard(context=context).scrub(payload, warnings=warnings)
