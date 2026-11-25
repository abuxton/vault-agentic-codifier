# terraform-vault-vault-codifier: codifier targets. The Vault harness has its own Makefile in test/.
# Every target exits non-zero on failure. TERRAFORM, TFLINT and RAW/OUT can be overridden.
SHELL := /bin/bash
export PATH := $(PATH):$(HOME)/.local/bin:/opt/homebrew/bin
RAW ?= discovered_terraform/raw
OUT ?= discovered_terraform/terraform

.DEFAULT_GOAL := help
.PHONY: help assemble ownership static-gate zero-diff verify verify-selftest variants

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

assemble: ## Run the seven generators in order, then the ownership check and validate (TASK-022)
	bash skills/codification-layer-assembly/scripts/assemble.sh $(RAW) $(OUT)

ownership: ## Check ownership, labels, imports and provenance of the generated layers (TASK-022)
	bash skills/codification-layer-assembly/scripts/check.sh $(OUT)

static-gate: ## terraform validate, fmt -check and tflint in every layer (TASK-023)
	bash skills/validation-static-gate/scripts/gate.sh $(OUT)

zero-diff: ## Import into a scratch state and require plan exit 0 per layer; needs VAULT_TOKEN, harness only (TASK-024)
	bash skills/validation-zero-diff/scripts/zero-diff.sh $(OUT)

verify: ## Audit log is read-only for the discovery window and no secret is in the output (TASK-025)
	bash skills/validation-readonly-secrets/scripts/verify.sh $(OUT) $(RAW)

verify-selftest: ## Inject faults; the verifier must catch every one (TASK-025)
	bash skills/validation-readonly-secrets/scripts/verify.sh --selftest

variants: ## Edge-case fixtures on throwaway containers; the real harness is not touched (TASK-026)
	bash skills/validation-variants/scripts/run-variants.sh
