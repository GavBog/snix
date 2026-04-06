let
  depot = (import ../..) { };
  machines = depot.ops.machines;
  mkColmenaConfig =
    targetHost: config:
    { ... }:
    {
      imports = [ config ];
      deployment = { inherit targetHost; };
    };
in

{
  meta = {
    nixpkgs = depot.third_party.nixpkgs;
    specialArgs = { inherit depot; };
  };

  # TODO: archivist-ec2
  build03 = mkColmenaConfig "build03.infra.snix.dev" machines.build03;
  gerrit01 = mkColmenaConfig "gerrit01.infra.snix.dev" machines.gerrit01;
  meta01 = mkColmenaConfig "meta01.infra.snix.dev" machines.meta01;
  public01 = mkColmenaConfig "public01.infra.snix.dev" machines.public01;
  snix-cache = mkColmenaConfig "nixos.snix.store" machines.snix-cache;
}
