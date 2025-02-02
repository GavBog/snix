# Configure TVL Keycloak instance.
#
# TODO(tazjin): Configure GitLab IDP

terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }

  backend "s3" {
    endpoints = {
      s3 = "https://objects.dc-sto1.glesys.net"
    }
    bucket = "tvl-state"
    key    = "terraform/tvl-keycloak"
    region = "glesys"

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

provider "keycloak" {
  client_id = "terraform"
  url       = "https://auth.tvl.fyi"
  # NOTE: Docs mention this applies to "users of the legacy distribution of keycloak".
  # However, we get a "failed to perform initial login to Keycloak: error
  # sending POST request to https://auth.tvl.fyi/realms/master/protocol/openid-connect/token: 404 Not Found"
  # if we don't set this.
  base_path = "/auth"
}

resource "keycloak_realm" "tvl" {
  realm                       = "TVL"
  enabled                     = true
  display_name                = "The Virus Lounge"
  default_signature_algorithm = "RS256"

  smtp_server {
    from              = "tvlbot@tazj.in"
    from_display_name = "The Virus Lounge"
    host              = "127.0.0.1"
    port              = "25"
    reply_to          = "depot@tvl.su"
    ssl               = false
    starttls          = false
  }
}
