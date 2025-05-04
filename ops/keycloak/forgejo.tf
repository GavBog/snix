resource "keycloak_openid_client" "forgejo" {
  realm_id                                 = keycloak_realm.snix.id
  client_id                                = "forgejo"
  name                                     = "snix Forgejo"
  enabled                                  = true
  access_type                              = "CONFIDENTIAL"
  standard_flow_enabled                    = true
  base_url                                 = "https://git.snix.dev"

  description                              = "snix project's code browsing, search and issue tracker"

  // disable full scope, roles are assigned via keycloak_generic_client_role_mapper
  full_scope_allowed    = false

  valid_redirect_uris = [
    "https://git.snix.dev/*",
  ]

  web_origins = [
    "https://git.snix.dev",
  ]
}

resource "keycloak_role" "forgejo_admin" {
  realm_id    = keycloak_realm.snix.id
  client_id   = keycloak_openid_client.forgejo.id
  name        = "Admin"
  description = "Forgejo site admin and Snix Org Owner"
}

resource "keycloak_role" "forgejo_snix_contributors" {
  realm_id    = keycloak_realm.snix.id
  client_id   = keycloak_openid_client.forgejo.id
  name        = "Contributors"
  description = "Snix contributors"
}


# Add the "Contributors" role to all users
resource "keycloak_openid_hardcoded_role_protocol_mapper" "forgejo_hardcoded_role_mapper" {
  realm_id = keycloak_realm.snix.id
  client_id = keycloak_openid_client.forgejo.id
  name = "add forgejo contributors"
  role_id = keycloak_role.forgejo_snix_contributors.id
}

# Expose the above two roles at `forgejo_roles`
resource "keycloak_openid_user_client_role_protocol_mapper" "forgejo_role_mapper" {
  realm_id = keycloak_realm.snix.id
  client_id = keycloak_openid_client.forgejo.id
  name = "forgejo_roles mapper"

  claim_name = "forgejo_roles"
  claim_value_type = "String"
  add_to_id_token = true
  add_to_access_token = true
  multivalued = true

  # https://github.com/keycloak/terraform-provider-keycloak/issues/1016
  client_id_for_role_mappings = keycloak_openid_client.forgejo.client_id
}
