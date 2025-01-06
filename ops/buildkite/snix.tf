# Buildkite configuration for snix.

terraform {
  required_providers {
    buildkite = {
      source = "buildkite/buildkite"
    }
  }

  backend "s3" {
    endpoints = {
      s3 = "https://s3.dualstack.eu-central-1.amazonaws.com"
    }

    bucket = "snix-tfstate"
    key    = "terraform/snix-buildkite"
    region = "eu-central-1"

    skip_credentials_validation = true
    skip_metadata_api_check = true
    skip_requesting_account_id  = true
  }
}

provider "buildkite" {
  organization = "snix"
}

resource "buildkite_cluster" "primary" {
  name           = "Primary cluster"
  description    = "Build everything and deploy"
  emoji          = "🚀"
  color          = "#bada55"

}

resource "buildkite_pipeline" "snix" {
  name           = "snix"
  description    = "Run full CI pipeline of the Snix monorepository."
  repository     = "https://cl.snix.dev/snix"
  steps          = file("./steps-snix.yml")
  default_branch = "refs/heads/canon"
  cluster_id = buildkite_cluster.primary.id
}

resource "buildkite_cluster_queue" "default" {
  cluster_id  = buildkite_cluster.primary.id
  key         = "default"
}
