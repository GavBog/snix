# DNS configuration for tvl.su

resource "glesys_dnsdomain" "tvl_su" {
  name = "tvl.su"
}

resource "glesys_dnsdomain_record" "tvl_su_NS1" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "@"
  type   = "NS"
  data   = "ns1.namesystem.se."
}

resource "glesys_dnsdomain_record" "tvl_su_NS2" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "@"
  type   = "NS"
  data   = "ns2.namesystem.se."
}

resource "glesys_dnsdomain_record" "tvl_su_NS3" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "@"
  type   = "NS"
  data   = "ns3.namesystem.se."
}

resource "glesys_dnsdomain_record" "tvl_su_apex_A" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "@"
  type   = "A"
  data   = var.whitby_ipv4
}

resource "glesys_dnsdomain_record" "tvl_su_apex_AAAA" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "@"
  type   = "AAAA"
  data   = var.whitby_ipv6
}

resource "glesys_dnsdomain_record" "tvl_su_whitby_A" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "whitby"
  type   = "A"
  data   = var.whitby_ipv4
}

resource "glesys_dnsdomain_record" "tvl_su_whitby_AAAA" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "whitby"
  type   = "AAAA"
  data   = var.whitby_ipv6
}

resource "glesys_dnsdomain_record" "tvl_su_sanduny_A" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "sanduny"
  type   = "A"
  data   = var.sanduny_ipv4
}

resource "glesys_dnsdomain_record" "tvl_su_sanduny_AAAA" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "sanduny"
  type   = "AAAA"
  data   = var.sanduny_ipv6
}

resource "glesys_dnsdomain_record" "cache_tvl_su_whitby_CNAME" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "cache"
  type   = "CNAME"
  data   = "whitby.tvl.su."
}

# Explicit records for all services running on whitby
resource "glesys_dnsdomain_record" "tvl_su_whitby_services" {
  domain   = glesys_dnsdomain.tvl_su.id
  type     = "CNAME"
  data     = "whitby.tvl.su."
  ttl      = 60
  host     = each.key
  for_each = toset(local.whitby_services)
}

# Explicit records for all services running on nevsky
resource "glesys_dnsdomain_record" "tvl_su_nevsky_services" {
  domain   = glesys_dnsdomain.tvl_su.id
  type     = "CNAME"
  data     = "nevsky.tvl.su."
  host     = each.key
  ttl      = 600
  for_each = toset(local.nevsky_services)
}

# Explicit records for all services running on bugry
resource "glesys_dnsdomain_record" "tvl_su_bugry_services" {
  domain   = glesys_dnsdomain.tvl_su.id
  type     = "CNAME"
  data     = "bugry.tvl.su."
  host     = each.key
  ttl      = 600
  for_each = toset(local.bugry_services)
}

# historical tvixbolt.tvl.su record, redirects to bolt.tvix.dev
resource "glesys_dnsdomain_record" "tvix_su_tvixbolt_CNAME" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "tvixbolt"
  type   = "CNAME"
  data   = "whitby.tvl.su."
}

resource "glesys_dnsdomain_record" "tvl_su_inbox_CNAME" {
  domain = glesys_dnsdomain.tvl_su.id
  type   = "CNAME"
  data   = "sanduny.tvl.su."
  host   = "inbox.tvl.su."
}

resource "glesys_dnsdomain_record" "tvl_su_TXT_google_site" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "@"
  type   = "TXT"
  data   = "google-site-verification=3ksTBzFK3lZlzD3ddBfpaHs9qasfAiYBmvbW2T_ejH4"
}

# Yandex 360 setup

resource "glesys_dnsdomain_record" "tvl_su_TXT_yandex" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "@"
  type   = "TXT"
  data   = "yandex-verification: b99c43b7838949dc"
}

resource "glesys_dnsdomain_record" "tvl_su_MX_yandex" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "@"
  type   = "MX"
  data   = "10 mx.yandex.net."
}

resource "glesys_dnsdomain_record" "tvl_su_TXT_yandex_spf" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "@"
  type   = "TXT"
  data   = "v=spf1 redirect=_spf.yandex.net"

}

resource "glesys_dnsdomain_record" "tvl_su_TXT_yandex_dkim" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "mail._domainkey"
  type   = "TXT"
  data   = "v=DKIM1; k=rsa; t=s; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDaRdWF8BtCHlTTQN8O+E5Qn27FVIpUEAdk1uq2vdIKh1Un/3NfdWtxStcS1Mf0iEprt1Fb4zgWOkDlPi+hH/UZqiC9QNeNqEBGMB9kgJyfsUt6cDCIVGvn8PT9JcZW1jxSziOj8nUWB4noqbaVcQNqNbwtaHPm3aifwKwScxVO7wIDAQAB"
}

resource "glesys_dnsdomain_record" "tvl_su_CNAME_yandex_mail" {
  domain = glesys_dnsdomain.tvl_su.id
  host   = "mail"
  type   = "CNAME"
  data   = "domain.mail.yandex.net."
}
