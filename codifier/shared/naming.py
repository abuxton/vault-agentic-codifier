"""
naming — deterministic Terraform identifier and file-path library.

Implements: TASK-003
Spec ref:   specs.md §CAC5 (deterministic), CAC6 (idempotent), CAP-006 AC6 (collision)
            specs.md §Resource naming convention
Doc ref:    https://developer.hashicorp.com/vault/docs
            https://developer.hashicorp.com/terraform/language/syntax/configuration

Rules implemented
─────────────────
1. A Terraform resource label is a valid identifier: starts with a letter or
   underscore; subsequent characters are letters, digits, `_`, or `-`.
   (Terraform actually allows `-` in labels but most tooling normalises to `_`;
   we always use `_` for determinism.)
2. Segments from namespace paths, mount paths, and object names are
   normalised: `/` → `_`, `-` → `_`, `+` → `_`, `.` → `_`, space → `_`,
   then de-duplicated runs of `_`.
3. If the first character is a digit, the label is prefixed with `v_`.
4. For collision handling (same name in different namespaces): the full
   namespace prefix is prepended before the object name.  A collision
   registry per output directory tracks uniqueness across a run.
5. Policy file paths: `policies/<namespace>/<name>.hcl`, where namespace and
   name are normalised (but NOT slugified — the HCL file name preserves the
   original Vault name, only `/` → `__` to avoid directory creation).
6. Reference-address helper: given a resource type and label it returns the
   canonical `<type>.<label>` Terraform reference string, optionally with
   an attribute (e.g. `vault_namespace.admin.path`).

All public functions are pure (no I/O, no global state) except for
CollisionRegistry which is explicitly stateful.
"""

from __future__ import annotations

import re
from typing import Dict, Optional, Set, Tuple

# ---------------------------------------------------------------------------
# Character-normalisation patterns
# ---------------------------------------------------------------------------

# Characters that become underscores
_TO_UNDERSCORE = re.compile(r"[/\-+. ]+")
# Runs of underscores (after substitution)
_MULTI_UNDERSCORE = re.compile(r"_{2,}")
# Strip leading/trailing underscores
_STRIP_OUTER = re.compile(r"^_+|_+$")
# Digits at start of an identifier
_LEADING_DIGIT = re.compile(r"^\d")


# ---------------------------------------------------------------------------
# Low-level normalisation
# ---------------------------------------------------------------------------

def _normalise_segment(segment: str) -> str:
    """
    Normalise a single path segment into a valid Terraform identifier fragment.

    Examples
    --------
    >>> _normalise_segment("admin/platform")
    'admin_platform'
    >>> _normalise_segment("my-secret-engine")
    'my_secret_engine'
    >>> _normalise_segment("42things")
    'v_42things'
    """
    if not segment:
        return "_empty"
    s = segment.lower()
    s = _TO_UNDERSCORE.sub("_", s)
    s = _MULTI_UNDERSCORE.sub("_", s)
    s = _STRIP_OUTER.sub("", s)
    if not s:
        return "_empty"
    if _LEADING_DIGIT.match(s):
        s = "v_" + s
    return s


def normalise(value: str) -> str:
    """
    Normalise a Vault path/name into a valid Terraform identifier.

    The full value (including embedded `/`) is treated as one unit, so
    `admin/platform/secret` becomes `admin_platform_secret`.

    Parameters
    ----------
    value:
        Any Vault namespace path, mount path, or object name.

    Returns
    -------
    str
        A valid Terraform identifier (never empty; never starts with a digit).
    """
    return _normalise_segment(value)


# ---------------------------------------------------------------------------
# Resource label derivation
# ---------------------------------------------------------------------------

def resource_label(
    name: str,
    namespace: str = "",
    *,
    include_namespace: bool = True,
) -> str:
    """
    Derive a Terraform resource label for an object in *namespace*.

    When ``include_namespace`` is True (default), the namespace prefix is
    prepended so that labels are globally unique across the generated output.

    Parameters
    ----------
    name:
        The Vault object name (e.g. policy name, mount path, namespace path).
    namespace:
        The Vault namespace in which the object lives (e.g. "admin/platform").
        Empty string means root namespace.
    include_namespace:
        If True, prepend the normalised namespace to the label.
        If False, use only the normalised name.

    Examples
    --------
    >>> resource_label("secret", namespace="admin/platform")
    'admin_platform_secret'
    >>> resource_label("admin", namespace="", include_namespace=False)
    'admin'
    >>> resource_label("synthetic-user-platform-sre", namespace="admin")
    'admin_synthetic_user_platform_sre'
    """
    norm_name = normalise(name)
    if not include_namespace or not namespace:
        return norm_name
    norm_ns = normalise(namespace)
    return f"{norm_ns}_{norm_name}"


def file_label(namespace: str, capability: str, suffix: str = "tf") -> str:
    """
    Derive a generated output file name.

    Examples
    --------
    >>> file_label("admin/platform", "auth_mounts")
    'admin_platform_auth_mounts.tf'
    """
    base = normalise(f"{namespace}_{capability}" if namespace else capability)
    return f"{base}.{suffix}"


# ---------------------------------------------------------------------------
# Policy file paths
# ---------------------------------------------------------------------------

def policy_file_path(namespace: str, policy_name: str) -> str:
    """
    Return the relative path for a policy HCL file within the output tree.

    The namespace is preserved as a directory component (using `__` for `/`)
    so that the file system does not create unexpected directories.  The
    policy name uses `__` for `/` as well.

    Format: ``policies/<namespace_path>/<policy_name>.hcl``

    Examples
    --------
    >>> policy_file_path("", "default-readonly")
    'policies/root/default-readonly.hcl'
    >>> policy_file_path("admin/platform", "app-sre")
    'policies/admin__platform/app-sre.hcl'
    """
    ns_part = namespace.replace("/", "__") if namespace else "root"
    name_part = policy_name.replace("/", "__")
    return f"policies/{ns_part}/{name_part}.hcl"


# ---------------------------------------------------------------------------
# Reference-address helper
# ---------------------------------------------------------------------------

def tf_reference(
    resource_type: str,
    label: str,
    attribute: Optional[str] = None,
) -> str:
    """
    Return a Terraform reference expression.

    Parameters
    ----------
    resource_type:
        e.g. ``"vault_namespace"``, ``"vault_policy"``.
    label:
        The resource label as returned by :func:`resource_label`.
    attribute:
        Optional attribute to append (e.g. ``"path"``, ``"name"``).

    Examples
    --------
    >>> tf_reference("vault_namespace", "admin")
    'vault_namespace.admin'
    >>> tf_reference("vault_policy", "admin_namespace_admin", "name")
    'vault_policy.admin_namespace_admin.name'
    """
    base = f"{resource_type}.{label}"
    return f"{base}.{attribute}" if attribute else base


# ---------------------------------------------------------------------------
# Collision registry (stateful — one per run / output directory)
# ---------------------------------------------------------------------------

class CollisionRegistry:
    """
    Tracks resource labels within a given output directory scope to ensure
    uniqueness across a single codification run.

    Usage
    -----
    ::

        reg = CollisionRegistry()
        label = reg.unique_label("vault_policy", "admin", namespace="")
        label2 = reg.unique_label("vault_policy", "admin", namespace="platform")
        # label  → "admin"   (first occurrence — no namespace needed)
        # label2 → "platform_admin"  (collision resolved by prepending ns)
    """

    def __init__(self) -> None:
        # {resource_type: {label: (namespace, name)}}
        self._registry: Dict[str, Dict[str, Tuple[str, str]]] = {}

    def _seen(self, resource_type: str) -> Dict[str, Tuple[str, str]]:
        return self._registry.setdefault(resource_type, {})

    def unique_label(
        self,
        resource_type: str,
        name: str,
        namespace: str = "",
    ) -> str:
        """
        Return a unique Terraform resource label for the given object.

        If the bare normalised name has not been used for this resource type,
        it is returned as-is.  On collision, the full namespace-qualified
        label is returned instead.  If even that is taken, a numeric suffix
        is appended.

        Parameters
        ----------
        resource_type:
            Terraform resource type (e.g. ``"vault_policy"``).
        name:
            The Vault object name.
        namespace:
            The Vault namespace path (empty = root).
        """
        seen = self._seen(resource_type)

        # Bare label (no namespace prefix)
        bare = normalise(name)

        # Full namespace-qualified label
        full = resource_label(name, namespace, include_namespace=bool(namespace))

        # Try bare first; allocate if free
        if bare not in seen:
            seen[bare] = (namespace, name)
            return bare

        # Already allocated to the same (ns, name)? return it.
        if seen[bare] == (namespace, name):
            return bare

        # Collision — use full qualified label
        if full not in seen:
            seen[full] = (namespace, name)
            return full

        if seen[full] == (namespace, name):
            return full

        # Both taken — append numeric suffix
        counter = 2
        while True:
            candidate = f"{full}_{counter}"
            if candidate not in seen:
                seen[candidate] = (namespace, name)
                return candidate
            counter += 1

    def all_labels(self, resource_type: str) -> Set[str]:
        """Return all labels registered for *resource_type*."""
        return set(self._seen(resource_type).keys())


# ---------------------------------------------------------------------------
# Convenience: harness mapping validation examples (from TASK-003 AC4)
# ---------------------------------------------------------------------------
_EXPECTED_MAPPINGS: Tuple[Tuple[str, str, str], ...] = (
    # (namespace, name, expected_label)
    ("admin/platform", "secret", "admin_platform_secret"),
    ("admin", "synthetic-user-platform-sre", "admin_synthetic_user_platform_sre"),
    ("", "default-readonly", "default_readonly"),
    ("admin", "default-readonly", "admin_default_readonly"),
)


def validate_harness_mappings() -> bool:
    """
    Assert that the harness examples from TASK-003 AC4 produce expected labels.

    Raises AssertionError on mismatch.  Used in unit tests and the CLI
    ``python -m codifier validate-naming``.
    """
    for ns, name, expected in _EXPECTED_MAPPINGS:
        actual = resource_label(name, ns, include_namespace=bool(ns))
        assert actual == expected, (
            f"Naming mismatch: resource_label({name!r}, {ns!r}) → {actual!r}, "
            f"expected {expected!r}"
        )
    return True
