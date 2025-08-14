resource "keycloak_openid_client" "nb_grafana" {
  realm_id              = keycloak_realm.snix.id
  client_id             = "nb_grafana"
  name                  = "Grafana (Nar-bridge)"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  base_url              = "https://nixos.snix.store/grafana"

  // disable full scope, roles are assigned via keycloak_openid_user_client_role_protocol_mapper
  full_scope_allowed    = false

  valid_redirect_uris = [
    "https://nixos.snix.store/grafana/*",
  ]

   valid_post_logout_redirect_uris = [
    "https://nixos.snix.store/grafana/",
  ]
}

resource "keycloak_role" "nb_grafana_editor" {
  realm_id    = keycloak_realm.snix.id
  client_id   = keycloak_openid_client.nb_grafana.id
  name        = "Editor"
  description = "Can edit things in Nar-bridge's Grafana"
}

resource "keycloak_role" "nb_grafana_admin" {
  realm_id    = keycloak_realm.snix.id
  client_id   = keycloak_openid_client.nb_grafana.id
  name        = "Admin"
  description = "Can admin things in Nar-bridge's Grafana"
}

# Expose the above two roles at `grafana_roles`
resource "keycloak_openid_user_client_role_protocol_mapper" "nb_grafana_role_mapper" {
  realm_id = keycloak_realm.snix.id
  client_id = keycloak_openid_client.nb_grafana.id
  name = "nb_grafana_roles mapper"

  claim_name = "nb_grafana_roles"
  claim_value_type = "String"
  add_to_id_token = true
  add_to_access_token = true
  multivalued = true

  # https://github.com/keycloak/terraform-provider-keycloak/issues/1016
  client_id_for_role_mappings = keycloak_openid_client.nb_grafana.client_id
}

# It seems this is necessary
resource "keycloak_openid_client_default_scopes" "nb_grafana_default_scopes" {
  realm_id  = keycloak_realm.snix.id
  client_id = keycloak_openid_client.nb_grafana.id

  default_scopes = [
    "profile",
    "email",
    "roles",
  ]
}
