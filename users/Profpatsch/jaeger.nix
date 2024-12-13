{ depot, pkgs, ... }:
let
  drv =
    pkgs.stdenv.mkDerivation {
      pname = "jaeger";
      version = "1.49.0";
      src = pkgs.fetchurl {
        url = "https://github.com/jaegertracing/jaeger/releases/download/v1.49.0/jaeger-1.49.0-linux-amd64.tar.gz";
        hash = "sha256-QhxISDlk/t431EesgVkHWTe7yiw2B+yyfq//GLP0As4=";
      };
      phases = [ "unpackPhase" "installPhase" "fixupPhase" ];
      installPhase = ''
        mkdir -p $out/bin
        install ./jaeger-all-in-one $out/bin
      '';
    };
  image =
    pkgs.dockerTools.buildImage {
      name = "jaeger";
      tag = "1.49.0";
      copyToRoot = drv;
      config = {
        Cmd = [ "/bin/jaeger-all-in-one" ];
      };

    };

  runner =
    depot.nix.writeExecline "jaeger-docker-run" { } [
      "if"
      [ "docker" "load" "-i" image ]
      "docker"
      "run"
      "--rm"
      "--name"
      "jaeger"
      # Web UI
      "-p"
      "16686:16686"
      # Opentelemetry
      "-p"
      "4318:4318"
      "jaeger:1.49.0"
      "jaeger-all-in-one"
      "$@"
    ];
in
runner
