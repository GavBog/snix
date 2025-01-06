DNS configuration
=================

This folder contains configuration for our DNS zones. The zones are hosted with
Digital Ocean DNS, which possess a Terraform provider for DNS records.

Secrets are needed for applying this. The encrypted file
`//ops/secrets/tf-dns.age` contains `export` calls which should be
sourced, for example via `direnv`, by users with the appropriate
credentials.

Here is an example `direnv` configuration:

```
# //ops/secrets/.envrc
source_up
eval $(age --decrypt -i ~/.ssh/id_ed25519 $(git rev-parse --show-toplevel)/ops/secrets/tf-dns.age)
watch_file $(git rev-parse --show-toplevel)/secrets/tf-dns.age
```
