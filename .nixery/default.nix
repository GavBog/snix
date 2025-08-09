# See README.md
{
  depot ? import ../. { },
  ...
}:

depot.third_party.nixpkgs.extend (
  _: _: {
    tvl = depot;
  }
)
