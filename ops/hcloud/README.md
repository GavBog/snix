Hetzner cloud configuration
=======================

This contains Terraform configuration for setting up our Hetzner cloud resources, except S3, see `//ops//hetzner-s3` for this.

Through `//tools/depot-deps` a `tf-hcloud` binary is made available
which contains a Terraform binary pre-configured with the correct
providers. This is automatically on your `$PATH` through `direnv`.

However, secrets still need to be loaded to access the Terraform state
and speak to the Hetzner API. These are available to certain users
through `//ops/secrets`.

This can be done with separate direnv configuration, for example:

```
# //ops/buildkite/.envrc
source_up
eval $(age --decrypt -i ~/.ssh/id_ed25519 $(git rev-parse --show-toplevel)/ops/secrets/tf-hcloud.age)
```
