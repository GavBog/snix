# DNS configuration for snix.systems

resource "digitalocean_domain" "snix_systems" {
  name = "snix.systems"
}

resource "digitalocean_record" "snix_systems_apex_v4" {
  domain   = digitalocean_domain.snix_systems.id
  type     = "A"
  name     = "@"
  value    = var.public01_ipv4
}

resource "digitalocean_record" "snix_systems_apex_v6" {
  domain   = digitalocean_domain.snix_systems.id
  type     = "AAAA"
  name     = "@"
  value    = var.public01_ipv6
}

# tvix.systems, old alias
resource "digitalocean_domain" "tvix_systems" {
  name = "tvix.systems"
}

resource "digitalocean_record" "tvix_systems_apex_v4" {
  domain   = digitalocean_domain.tvix_systems.id
  type     = "A"
  name     = "@"
  value    = var.public01_ipv4
}

resource "digitalocean_record" "tvix_systems_apex_v6" {
  domain   = digitalocean_domain.tvix_systems.id
  type     = "AAAA"
  name     = "@"
  value    = var.public01_ipv6
}
