# DNS configuration for tvix.dev

resource "glesys_dnsdomain" "tvix_dev" {
  name = "tvix.dev"
}

resource "glesys_dnsdomain_record" "tvix_dev_apex_A" {
  domain = glesys_dnsdomain.tvix_dev.id
  host   = "@"
  type   = "A"
  data   = var.bugry_ipv4
}

resource "glesys_dnsdomain_record" "tvix_dev_apex_AAAA" {
  domain = glesys_dnsdomain.tvix_dev.id
  host   = "@"
  type   = "AAAA"
  data   = var.bugry_ipv6
}

resource "glesys_dnsdomain_record" "tvix_dev_bolt_CNAME" {
  domain = glesys_dnsdomain.tvix_dev.id
  host   = "bolt"
  type   = "CNAME"
  data   = "bugry.tvl.fyi."
}

resource "glesys_dnsdomain_record" "tvix_dev_docs_CNAME" {
  domain = glesys_dnsdomain.tvix_dev.id
  host   = "docs"
  type   = "CNAME"
  data   = "bugry.tvl.fyi."
}

resource "glesys_dnsdomain_record" "tvix_dev_NS1" {
  domain = glesys_dnsdomain.tvix_dev.id
  host   = "@"
  type   = "NS"
  data   = "ns1.namesystem.se."
}

resource "glesys_dnsdomain_record" "tvix_dev_NS2" {
  domain = glesys_dnsdomain.tvix_dev.id
  host   = "@"
  type   = "NS"
  data   = "ns2.namesystem.se."
}

resource "glesys_dnsdomain_record" "tvix_dev_NS3" {
  domain = glesys_dnsdomain.tvix_dev.id
  host   = "@"
  type   = "NS"
  data   = "ns3.namesystem.se."
}
