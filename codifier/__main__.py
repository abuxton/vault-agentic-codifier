#!/usr/bin/env python3
"""
vault-brownfield-codifier — entry point.

Usage:
    python3 -m codifier [OPTIONS]

Options:
    --vault-addr ADDR        Vault address (default: $VAULT_ADDR)
    --vault-token TOKEN      Vault token (default: $VAULT_TOKEN)
    --namespace-style STYLE  'aliased' (default) or 'namespace'
    --output-dir DIR         Output directory (default: discovered_terraform)
    --raw-dir DIR            Raw payload directory (default: discovered_terraform/raw)
    --phase PHASE            Run only: discovery | codification | validation | all
    --dry-run                Print actions without writing files

Doc ref: https://developer.hashicorp.com/vault/docs
"""

import argparse
import os
import sys


def parse_args(argv=None):
    p = argparse.ArgumentParser(
        prog="vault-brownfield-codifier",
        description="Discover a brownfield Vault Enterprise cluster and codify it as Terraform HCL.",
    )
    p.add_argument(
        "--vault-addr",
        default=os.environ.get("VAULT_ADDR", ""),
        help="Vault address, e.g. http://127.0.0.1:8200 (default: $VAULT_ADDR)",
    )
    p.add_argument(
        "--vault-token",
        default=os.environ.get("VAULT_TOKEN", ""),
        help="Vault token (default: $VAULT_TOKEN). Never pass production tokens on the CLI.",
    )
    p.add_argument(
        "--namespace-style",
        choices=["aliased", "namespace"],
        default="aliased",
        help=(
            "How to target non-root namespaces in generated HCL. "
            "'aliased' uses provider = vault.<alias> (default, matches test harness). "
            "'namespace' uses the per-resource namespace argument."
        ),
    )
    p.add_argument(
        "--output-dir",
        default="discovered_terraform",
        help="Root output directory (default: discovered_terraform)",
    )
    p.add_argument(
        "--phase",
        choices=["discovery", "codification", "validation", "all"],
        default="all",
        help="Pipeline phase to run (default: all)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print planned actions without writing files or querying Vault",
    )
    return p.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    if not args.vault_addr:
        print("ERROR: --vault-addr or $VAULT_ADDR is required", file=sys.stderr)
        sys.exit(1)

    if not args.vault_token:
        print("ERROR: --vault-token or $VAULT_TOKEN is required", file=sys.stderr)
        sys.exit(1)

    if args.dry_run:
        print("[dry-run] vault-brownfield-codifier")
        print(f"  vault_addr:        {args.vault_addr}")
        print(f"  namespace_style:   {args.namespace_style}")
        print(f"  output_dir:        {args.output_dir}")
        print(f"  phase:             {args.phase}")
        print("  token:             [redacted]")
        return 0

    # Phase dispatch — modules are stubs until TASK-005 through TASK-022
    print(f"vault-brownfield-codifier  addr={args.vault_addr}  phase={args.phase}")
    print("NOTE: discovery and codification modules are not yet implemented (TASK-005+).")
    print("Run with --dry-run to verify argument parsing.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
