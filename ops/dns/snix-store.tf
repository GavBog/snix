# DNS configuration for snix.store

resource "digitalocean_domain" "snix_store" {
  name = "snix.store"
}

resource "digitalocean_record" "snix_store_nixos_v4" {
  domain   = digitalocean_domain.snix_store.id
  type     = "A"
  name     = "nixos"
  value    = "37.27.128.134"
}

resource "digitalocean_record" "snix_store_nixos_v6" {
  domain   = digitalocean_domain.snix_store.id
  type     = "AAAA"
  name     = "nixos"
  value    = "2a01:4f9:3071:1091::2"
}

# tvix.store, old alias
resource "digitalocean_domain" "tvix_store" {
  name = "tvix.store"
}

resource "digitalocean_record" "tvix_store_nixos_cname" {
  domain   = digitalocean_domain.tvix_store.id
  type     = "CNAME"
  name     = "nixos"
  value    = "nixos.snix.store."
}
