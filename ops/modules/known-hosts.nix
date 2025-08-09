# Configure public keys for SSH hosts known to the snix project.
{ ... }:

{
  programs.ssh.knownHosts = {
    public01 = {
      hostNames = [
        "public01.infra.snix.dev"
        "git.snix.dev"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICzB7bqXWcv+sVokySvj1d74zRlVLSNqBw7/OY3c7QYd";
    };

    gerrit01 = {
      hostNames = [
        "gerrit01.infra.snix.dev"
        "cl.snix.dev"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN+RCLAExaM5EC70UsCPMtDT1Cfa80Ux/vex95fLk9S4";
    };

    build01 = {
      hostNames = [ "build01.infra.snix.dev" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEteVaeN/FEAY8yyGWdAbv6+X6yv2m8+4F5qZEAhxW9f";
    };

    github = {
      hostNames = [ "github.com" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
  };
}
