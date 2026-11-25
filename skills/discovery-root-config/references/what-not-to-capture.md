## 7. What NOT to Capture

The following items are server configuration file concerns and must **NEVER** be codified into Terraform:
- **Raw License File / Text (`/sys/license`)**: Managed via auto-load or server env vars.
- **Storage Backend Configuration**: Managed in server HCL (Raft, Consul, etc.).
- **Listener Stanzas**: IP, port, TLS certificate files on the host filesystem.
- **Entropy & HSM Pin Settings**: Physical or cloud KMS host credentials.
- **Unseal Keys and Master Keys**: Handled exclusively via unseal ceremonies.
