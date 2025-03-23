# All Keycloak clients, that is applications which authenticate
# through Keycloak.
#
# Includes first-party (i.e. snix-hosted) and third-party clients.

resource "keycloak_openid_client" "grafana" {
  realm_id              = keycloak_realm.snix.id
  client_id             = "grafana"
  name                  = "Grafana"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  base_url              = "https://status.snix.dev"
  full_scope_allowed    = true

  valid_redirect_uris = [
    "https://status.snix.dev/*",
  ]
}

resource "keycloak_openid_client_default_scopes" "grafana_default_scopes" {
  realm_id  = keycloak_realm.snix.id
  client_id = keycloak_openid_client.grafana.id

  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
  ]
}

resource "keycloak_openid_client" "gerrit" {
  realm_id                                 = keycloak_realm.snix.id
  client_id                                = "gerrit"
  name                                     = "snix Gerrit"
  enabled                                  = true
  access_type                              = "CONFIDENTIAL"
  standard_flow_enabled                    = true
  base_url                                 = "https://cl.snix.dev"
  description                              = "snix project's code review tool"
  direct_access_grants_enabled             = true
  exclude_session_state_from_auth_response = false

  valid_redirect_uris = [
    "https://cl.snix.dev/*",
  ]

  web_origins = [
    "https://cl.snix.dev",
  ]
}

resource "keycloak_openid_client" "forgejo" {
  realm_id                                 = keycloak_realm.snix.id
  client_id                                = "forgejo"
  name                                     = "snix Forgejo"
  enabled                                  = true
  access_type                              = "CONFIDENTIAL"
  standard_flow_enabled                    = true
  base_url                                 = "https://git.snix.dev"
  description                              = "snix project's code browsing, search and issue tracker"
  direct_access_grants_enabled             = true
  exclude_session_state_from_auth_response = false

  valid_redirect_uris = [
    "https://git.snix.dev/*",
  ]

  web_origins = [
    "https://git.snix.dev",
  ]
}

# resource "keycloak_saml_client" "buildkite" {
#   realm_id  = keycloak_realm.snix.id
#   client_id = "https://buildkite.com"
#   name      = "Buildkite"
#   base_url  = "https://buildkite.com/sso/snix"

#   client_signature_required   = false
#   assertion_consumer_post_url = "https://buildkite.com/sso/~/1531aca5-f49c-4151-8832-a451e758af4c/saml/consume"

#   valid_redirect_uris = [
#     "https://buildkite.com/sso/~/1531aca5-f49c-4151-8832-a451e758af4c/saml/consume"
#   ]
# }

# resource "keycloak_saml_user_attribute_protocol_mapper" "buildkite_email" {
#   realm_id                   = keycloak_realm.snix.id
#   client_id                  = keycloak_saml_client.buildkite.id
#   name                       = "buildkite-email-mapper"
#   user_attribute             = "email"
#   saml_attribute_name        = "email"
#   saml_attribute_name_format = "Unspecified"
# }

# resource "keycloak_saml_user_attribute_protocol_mapper" "buildkite_name" {
#   realm_id                   = keycloak_realm.snix.id
#   client_id                  = keycloak_saml_client.buildkite.id
#   name                       = "buildkite-name-mapper"
#   user_attribute             = "displayName"
#   saml_attribute_name        = "name"
#   saml_attribute_name_format = "Unspecified"
# }
