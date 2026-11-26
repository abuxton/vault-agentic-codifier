# ──────────────────────────────────────────────────────────────────────────────
# Sentinel fixtures, root namespace (stage 2, TASK-S02, CAP-008)
# Synthetic policies so discovery has an EGP and an RGP to read. Both rules
# always pass; they exist to be discovered and codified, not to enforce.
# ──────────────────────────────────────────────────────────────────────────────
resource "vault_egp_policy" "root_advisory" {
  name              = "synthetic-egp-root-advisory"
  paths             = ["secret/*", "auth/approle/*"]
  enforcement_level = "advisory"
  policy            = <<-EOT
    // SYNTHETIC fixture: always passes.
    main = rule { true }
  EOT
}

resource "vault_rgp_policy" "root_soft" {
  name              = "synthetic-rgp-root-soft"
  enforcement_level = "soft-mandatory"
  policy            = <<-EOT
    // SYNTHETIC fixture: always passes.
    main = rule { true }
  EOT
}
