#!/usr/bin/env bash
# Source this file. fixture_auth_config <namespace> <marker> <workdir>
# Enables LDAP, Kubernetes, AWS, cert, JWT and OIDC auth methods plus a token role in one namespace of a
# THROWAWAY cluster (never the committed harness), each with synthetic configuration. Every credential-like
# field carries <marker>, which must appear in no generated file, report or log (CAC10).
# Needs: vault (VAULT_ADDR and VAULT_TOKEN pointing at the scratch cluster), openssl.
fixture_auth_config() {
  local ns=$1 mk=$2 wd=$3 V="vault" bk="bindpass"
  mkdir -p "$wd"
  # a synthetic CA certificate (public material) and a synthetic public key, made at run time
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$wd/ca.key" -out "$wd/ca.pem" -days 30 -subj "/CN=synthetic-ca" >/dev/null 2>&1 || return 1
  openssl genrsa -out "$wd/jwt.key" 2048 >/dev/null 2>&1 && openssl rsa -in "$wd/jwt.key" -pubout -out "$wd/jwt.pub" >/dev/null 2>&1 || return 1

  $V policy read -namespace="$ns" default-readonly >/dev/null 2>&1 \
    || $V policy write -namespace="$ns" default-readonly - >/dev/null <<<'path "secret/data/*" { capabilities = ["read"] }' || return 1

  # LDAP: bind credential is the marker; one group and one user
  $V auth enable -namespace="$ns" ldap >/dev/null || return 1
  $V write -namespace="$ns" auth/ldap/config url=ldaps://ldap.example.internal userdn="ou=Users,dc=example,dc=internal" \
    userattr=uid binddn="cn=vault,dc=example,dc=internal" "${bk}=$mk-bp" groupdn="ou=Groups,dc=example,dc=internal" \
    groupattr=cn groupfilter='(|(memberUid={{.Username}})(member={{.UserDN}}))' connection_timeout=45 case_sensitive_names=true \
    userfilter='(&(uid={{.Username}})(objectClass=person))' token_ttl=10m token_policies=default-readonly >/dev/null || return 1
  $V write -namespace="$ns" auth/ldap/groups/synthetic-ldap-admins policies=default-readonly >/dev/null || return 1
  $V write -namespace="$ns" auth/ldap/users/synthetic-alice groups=synthetic-ldap-admins policies=default-readonly >/dev/null || return 1

  # Kubernetes: the reviewer JWT is the marker
  $V auth enable -namespace="$ns" kubernetes >/dev/null || return 1
  $V write -namespace="$ns" auth/kubernetes/config kubernetes_host=https://k8s.example.internal:6443 "token_reviewer_jwt=$mk-jwt" \
    kubernetes_ca_cert=@"$wd/ca.pem" disable_iss_validation=true >/dev/null || return 1
  $V write -namespace="$ns" auth/kubernetes/role/synthetic-app bound_service_account_names=app bound_service_account_namespaces=default \
    token_policies=default-readonly token_ttl=1h audience=vault >/dev/null || return 1
  $V write -namespace="$ns" auth/kubernetes/role/synthetic-ghost bound_service_account_names=ghost bound_service_account_namespaces=default \
    token_policies=does-not-exist-k8s audience=vault >/dev/null || return 1

  # AWS: access and secret key are markers
  $V auth enable -namespace="$ns" aws >/dev/null || return 1
  $V write -namespace="$ns" auth/aws/config/client "access_key=$mk-ak" "secret_key=$mk-sk" "iam_server_id_header_value=$mk-ih" \
    sts_region=eu-west-1 sts_endpoint=https://sts.eu-west-1.amazonaws.com max_retries=3 >/dev/null || return 1
  $V write -namespace="$ns" auth/aws/role/synthetic-iam auth_type=iam bound_iam_principal_arn="arn:aws:iam::123456789012:role/synthetic" resolve_aws_unique_ids=false \
    token_policies=default-readonly token_ttl=30m >/dev/null || return 1

  # cert: one trusted CA certificate
  $V auth enable -namespace="$ns" cert >/dev/null || return 1
  $V write -namespace="$ns" auth/cert/certs/synthetic-web certificate=@"$wd/ca.pem" display_name=synthetic-web \
    allowed_common_names=synthetic.example.internal token_policies=default-readonly >/dev/null || return 1

  # token role
  $V write -namespace="$ns" auth/token/roles/synthetic-ci allowed_policies=default-readonly orphan=true renewable=true \
    token_explicit_max_ttl=2h >/dev/null || return 1

  # JWT (static public key) and OIDC outside the admin namespace
  $V auth enable -namespace="$ns" -path=jwt jwt >/dev/null || return 1
  $V write -namespace="$ns" auth/jwt/config jwt_validation_pubkeys=@"$wd/jwt.pub" bound_issuer=https://issuer.example.internal >/dev/null || return 1
  $V write -namespace="$ns" auth/jwt/role/synthetic-ci role_type=jwt user_claim=sub bound_audiences=vault token_policies=default-readonly >/dev/null || return 1
  $V auth enable -namespace="$ns" -path=oidc oidc >/dev/null || return 1
  $V write -namespace="$ns" auth/oidc/config oidc_discovery_url=https://accounts.google.com oidc_client_id=synthetic-client \
    "oidc_client_secret=$mk-oc" default_role=synthetic-reader >/dev/null || return 1
  $V write -namespace="$ns" auth/oidc/role/synthetic-reader user_claim=sub allowed_redirect_uris=https://vault.example.internal/callback \
    oidc_scopes=openid token_policies=default-readonly bound_audiences=synthetic-client >/dev/null || return 1
}
