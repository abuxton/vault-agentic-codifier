ui             = true
log_level      = "info"
api_addr       = "http://127.0.0.1:8200"
cluster_addr   = "http://127.0.0.1:8201"
# Required in Vault >= 1.20: must be explicitly true or false.
# true is safe for local dev (Docker on macOS uses encrypted swap or no swap).
disable_mlock  = true

# Integrated (Raft) storage — mirrors a real Enterprise deployment
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-local-dev-node1"

  retry_join {
    leader_api_addr = "http://127.0.0.1:8200"
  }
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = true   # local dev only — never disable TLS in production
}

# Enterprise licence path inside the container.
# The file is bind-mounted from the host at run time; it is NEVER baked into
# the image and NEVER committed to source control (see test/.gitignore).
license_path = "/vault/license/vault.hclic"
