.DEFAULT_GOAL := help

VAULT_ADDR  ?= http://127.0.0.1:8200
VAULT_TOKEN ?= root

# Explicit paths for tools not on PATH in non-interactive shells
VAULT_BIN   ?= /opt/homebrew/bin/vault
TF_BIN      ?= /opt/homebrew/bin/terraform
DOCKER_BIN  ?= /usr/local/bin/docker

# Licence lives in ./tmp/vault.hclic (repo root, excluded from git).
# Docker Desktop shares the user home directory so this path mounts cleanly.
VAULT_LICENSE_SRC ?= $(abspath $(dir $(MAKEFILE_LIST))../tmp/vault.hclic)

TF_ADMIN = terraform/admin
TF_NS    = terraform/namespaces
TF_SEED  = terraform/seed

# ──────────────────────────────────────────────────────────────────────────────
# Colours
# ──────────────────────────────────────────────────────────────────────────────
RESET  := \033[0m
BOLD   := \033[1m
GREEN  := \033[32m
YELLOW := \033[33m
CYAN   := \033[36m
RED    := \033[31m

define header
	@printf "\n$(BOLD)$(CYAN)► %s$(RESET)\n" "$(1)"
endef

# ──────────────────────────────────────────────────────────────────────────────
# Help
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: help
help: ## Show this help
	@printf "\n$(BOLD)terraform-vault-vault-codifier — test harness$(RESET)\n\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(RESET) %s\n", $$1, $$2}'
	@printf "\n$(YELLOW)Prerequisites$(RESET)\n"
	@printf "  • Docker + Docker Compose installed\n"
	@printf "  • Vault Enterprise licence at $(VAULT_LICENSE_SRC)\n"
	@printf "  • terraform >= 1.9 on PATH\n"
	@printf "  • vault CLI >= 1.17 on PATH\n"
	@printf "  • jq on PATH\n\n"
	@printf "$(YELLOW)Dev mode$(RESET)\n"
	@printf "  Root token is always: $(GREEN)root$(RESET)\n"
	@printf "  Storage is in-memory — data lost on container stop.\n\n"

# ──────────────────────────────────────────────────────────────────────────────
# Guard: licence must exist before starting
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: guard-license
guard-license:
	@test -f "$(VAULT_LICENSE_SRC)" || \
		(printf "$(RED)ERROR:$(RESET) Vault Enterprise licence not found.\n\n" && \
		printf "Expected: $(VAULT_LICENSE_SRC)\n\n" && \
		printf "Copy your licence to ./tmp/vault.hclic (never committed to source control).\n\n" && \
		exit 1)
	@printf "$(GREEN)✓$(RESET) Licence found at $(VAULT_LICENSE_SRC)\n"

# ──────────────────────────────────────────────────────────────────────────────
# Vault lifecycle
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: start
start: guard-license ## Start Vault Enterprise dev-mode container
	$(call header,Starting Vault Enterprise 2.2.2+ent — dev mode)
	docker compose up -d
	@printf "Waiting for Vault"
	@for i in $$(seq 1 30); do \
		if curl -sf $(VAULT_ADDR)/v1/sys/health > /dev/null 2>&1; then \
			printf " $(GREEN)✓$(RESET)\n"; break; \
		fi; \
		printf "."; sleep 1; \
	done
	@printf "$(GREEN)Vault is ready.$(RESET)\n"
	@printf "  Address:    $(VAULT_ADDR)\n"
	@printf "  Root token: root\n"
	@printf "  UI:         $(VAULT_ADDR)/ui\n\n"

.PHONY: stop
stop: ## Stop the Vault container (data lost — dev mode)
	$(call header,Stopping Vault)
	docker compose stop

.PHONY: destroy
destroy: ## Remove container (destructive)
	$(call header,Removing Vault container)
	docker compose down
	@rm -f .vault-env

.PHONY: logs
logs: ## Tail Vault container logs
	docker compose logs -f vault

.PHONY: status
status: ## Show Vault status
	@VAULT_CONFIG_PATH=/dev/null VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN=$(VAULT_TOKEN) \
		vault status 2>&1 || true

# ──────────────────────────────────────────────────────────────────────────────
# Credentials helper
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: env
env: ## Write .vault-env with address + root token for sourcing into shell
	$(call header,Writing .vault-env)
	@printf "export VAULT_ADDR=$(VAULT_ADDR)\nexport VAULT_TOKEN=root\n" > .vault-env
	@printf "$(GREEN)Done.$(RESET) Run: $(BOLD)source test/.vault-env$(RESET)\n"

# ──────────────────────────────────────────────────────────────────────────────
# Combined convenience
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: up
up: start env ## Start container and write credentials to .vault-env

.PHONY: reset
reset: destroy up ## Full teardown + fresh start + re-seed

# ──────────────────────────────────────────────────────────────────────────────
# Terraform helpers
# ──────────────────────────────────────────────────────────────────────────────
define tf_init
	@cd $(1) && terraform init -upgrade -input=false
endef

define tf_apply
	@cd $(1) && VAULT_TOKEN=root \
		terraform apply -auto-approve -input=false \
			-var="vault_address=$(VAULT_ADDR)" \
			-var="vault_token=root"
endef

define tf_destroy
	@cd $(1) && VAULT_TOKEN=root \
		terraform destroy -auto-approve -input=false \
			-var="vault_address=$(VAULT_ADDR)" \
			-var="vault_token=root"
endef

define tf_fmt
	@cd $(1) && terraform fmt -recursive
endef

define tf_validate
	@cd $(1) && \
		terraform init -backend=false -input=false > /dev/null && \
		terraform validate
endef

# ──────────────────────────────────────────────────────────────────────────────
# Seed — apply all Terraform layers in dependency order
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: tf-init
tf-init: ## terraform init all layers
	$(call header,Initialising Terraform layers)
	$(call tf_init,$(TF_ADMIN))
	$(call tf_init,$(TF_NS))
	$(call tf_init,$(TF_SEED))

.PHONY: seed
seed: tf-init ## Apply all Terraform layers: admin → namespaces → seed data
	$(call header,Applying admin layer)
	$(call tf_apply,$(TF_ADMIN))
	$(call header,Applying namespaces layer)
	$(call tf_apply,$(TF_NS))
	$(call header,Applying seed layer)
	$(call tf_apply,$(TF_SEED))

.PHONY: seed-destroy
seed-destroy: ## Destroy all Terraform seed data (reverse order)
	$(call header,Destroying seed layer)
	$(call tf_destroy,$(TF_SEED))
	$(call header,Destroying namespaces layer)
	$(call tf_destroy,$(TF_NS))
	$(call header,Destroying admin layer)
	$(call tf_destroy,$(TF_ADMIN))

# ──────────────────────────────────────────────────────────────────────────────
# Format + Validate
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: fmt
fmt: ## Format all Terraform in test/
	$(call header,Formatting Terraform)
	$(call tf_fmt,$(TF_ADMIN))
	$(call tf_fmt,$(TF_NS))
	$(call tf_fmt,$(TF_SEED))

.PHONY: validate
validate: ## Validate all Terraform in test/
	$(call header,Validating Terraform)
	$(call tf_validate,$(TF_ADMIN))
	$(call tf_validate,$(TF_NS))
	$(call tf_validate,$(TF_SEED))

# ──────────────────────────────────────────────────────────────────────────────
# Full workflow
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: all
all: up seed ## Full workflow: start Vault dev, write env, seed synthetic data

.PHONY: clean
clean: seed-destroy destroy ## Destroy seed data then destroy Vault container

# ──────────────────────────────────────────────────────────────────────────────
# Smoke test — verify the full stack is working
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: smoke-test
smoke-test: ## Verify Vault is up and all namespaces + secrets are accessible
	$(call header,Smoke test)
	@export VAULT_CONFIG_PATH=/dev/null VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN=root; \
	printf "  Vault status ... "; \
	$(VAULT_BIN) status -format=json | jq -e '.initialized == true and .sealed == false' > /dev/null \
		&& printf "$(GREEN)OK$(RESET)\n" || (printf "$(RED)FAIL$(RESET)\n" && exit 1); \
	\
	printf "  Namespaces ... "; \
	$(VAULT_BIN) namespace list -format=json 2>/dev/null | jq -e 'map(select(. == "admin/")) | length > 0' > /dev/null \
		&& printf "$(GREEN)OK$(RESET)\n" || (printf "$(RED)FAIL$(RESET)\n" && exit 1); \
	\
	printf "  Admin auth mounts ... "; \
	VAULT_NAMESPACE=admin $(VAULT_BIN) auth list -format=json 2>/dev/null | jq -e 'has("approle/")' > /dev/null \
		&& printf "$(GREEN)OK$(RESET)\n" || (printf "$(RED)FAIL$(RESET)\n" && exit 1); \
	\
	printf "  platform/secret KV mount ... "; \
	VAULT_NAMESPACE=admin/platform $(VAULT_BIN) secrets list -format=json 2>/dev/null | jq -e 'has("secret/")' > /dev/null \
		&& printf "$(GREEN)OK$(RESET)\n" || (printf "$(RED)FAIL$(RESET)\n" && exit 1); \
	\
	printf "  billing KV read ... "; \
	VAULT_NAMESPACE=admin/app-billing $(VAULT_BIN) kv get -mount=secret billing-service/checkout 2>/dev/null | grep -q "SYNTHETIC" \
		&& printf "$(GREEN)OK$(RESET)\n" || (printf "$(RED)FAIL$(RESET)\n" && exit 1); \
	\
	printf "  identity KV read ... "; \
	VAULT_NAMESPACE=admin/app-identity $(VAULT_BIN) kv get -mount=secret identity-service/ldap 2>/dev/null | grep -q "SYNTHETIC" \
		&& printf "$(GREEN)OK$(RESET)\n" || (printf "$(RED)FAIL$(RESET)\n" && exit 1); \
	\
	printf "\n$(BOLD)$(GREEN)All smoke tests passed.$(RESET)\n\n"
