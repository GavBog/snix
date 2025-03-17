variable "github_client_secret" {
  type = string
}

variable "gitlab_client_secret" {
  type = string
}

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

  authorization_url = ""
  token_url         = ""
}

resource "keycloak_oidc_identity_provider" "gitlab" {
  alias                 = "gitlab"
  provider_id           = "gitlab"
  client_id             = "6ecb359ede53f7d80003d127dc4448bd1b1d73631a01273d9576e00ff9a94d2c"
  client_secret         = var.gitlab_client_secret
  realm                 = keycloak_realm.snix.id
  backchannel_supported = false
  gui_order             = "2"
  store_token           = false
  sync_mode             = "IMPORT"
  trust_email           = true
  default_scopes        = "openid read_user"

  authorization_url = ""
  token_url         = ""
}
