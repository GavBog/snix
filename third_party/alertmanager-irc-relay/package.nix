{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "alertmanager-irc-relay";
  version = "0.5.1";

  src = fetchFromGitHub {
    owner = "google";
    repo = "alertmanager-irc-relay";
    rev = "v${version}";
    hash = "sha256-Rl7o2QPa/IU1snlx/LiJxQok9pnkw9XANnJsu41vNlY=";
  };

  vendorHash = "sha256-KX+TR0n14+95lldF+0KUo5DbqOKpUDaZNuKMBf0KHFQ=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Send Prometheus Alerts to IRC using Webhooks";
    homepage = "https://github.com/google/alertmanager-irc-relay";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ raitobezarius ];
    mainProgram = "alertmanager-irc-relay";
  };
}
