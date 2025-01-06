# All user sources, that is services from which Keycloak gets user
# information (either by accessing a system like LDAP or integration
# through protocols like OIDC).

variable "github_client_secret" {
  type = string
}

# keycloak_oidc_identity_provider.github will be destroyed
# (because keycloak_oidc_identity_provider.github is not in configuration)
resource "keycloak_oidc_identity_provider" "github" {
  alias                 = "github"
  provider_id           = "github"
  client_id             = "Ov23liKpXqs0aPaVgDpg"
  client_secret         = var.github_client_secret
  realm                 = keycloak_realm.snix.id
  backchannel_supported = false
  gui_order             = "1"
  store_token           = false
  sync_mode             = "IMPORT"
  trust_email           = true
  default_scopes        = "openid user:email"

  # These default to built-in values for the `github` provider_id.
  authorization_url = ""
  token_url         = ""
}
