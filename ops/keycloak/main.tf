# Configure snix's Keycloak instance.

terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
    }
  }

  backend "s3" {
    endpoints = {
      s3 = "https://s3.dualstack.eu-central-1.amazonaws.com"
    }

    bucket = "snix-tfstate"
    key    = "terraform/snix-keycloak"
    region = "eu-central-1"

    skip_credentials_validation = true
    skip_metadata_api_check = true
    skip_requesting_account_id  = true
  }
}

provider "keycloak" {
  client_id = "terraform"
  url       = "https://auth.snix.dev"
}

resource "keycloak_realm" "snix" {
  realm                       = "snix-project"
  enabled                     = true
  display_name                = "The snix project"
  default_signature_algorithm = "RS256"

  # smtp_server {
  #   from              = "tvlbot@tazj.in"
  #   from_display_name = "The Virus Lounge"
  #   host              = "127.0.0.1"
  #   port              = "25"
  #   reply_to          = "depot@tvl.su"
  #   ssl               = false
  #   starttls          = false
  # }
}
