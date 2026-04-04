{ ... }:
{
  imports = [
    ./base.nix
  ];

  # Microbenchmark
  # hyperfine --warmup 1 'rm -rf /tmp/cache; nix copy --from https://nixos.snix.store/ --to "file:///tmp/cache?compression=none" /nix/store/jlkypcf54nrh4n6r0l62ryx93z752hb2-firefox-132.0'
  services.nginx = {
    virtualHosts."nixos.snix.store" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://unix:/run/nar-bridge.sock:/";
        extraConfig = ''
          # Sometimes it takes a while to download and unpack from upstream.
          proxy_read_timeout 180s;

          # Restrict allowed HTTP methods
          limit_except GET HEAD {
            # nar bridge allows to upload nars via PUT
            deny all;
          }

          # Propagate content-encoding to the backend
          proxy_set_header Accept-Encoding $http_accept_encoding;

          # Enable proxy cache
          proxy_cache nar-bridge;
          proxy_cache_key "$scheme$proxy_host$request_uri";
          proxy_cache_valid 200 301 302 10m;  # Cache responses for 10 minutes
          proxy_cache_valid 404 1m;  # Cache 404 responses for 1 minute
          proxy_cache_min_uses 2;  # Cache only if the object is requested at least twice
          proxy_cache_use_stale error timeout updating;
        '';
      };
    };
    virtualHosts."nixos.tvix.store" = {
      forceSSL = true;
      enableACME = true;
      locations."/".return = "301 https://nixos.snix.store$request_uri";
    };

    # use more cores for compression
    appendConfig = ''
      worker_processes auto;
    '';

    proxyCachePath."nar-bridge" = {
      enable = true;
      levels = "1:2";
      keysZoneName = "nar-bridge";
      # Put our 1TB NVME to good use
      maxSize = "200G";
      inactive = "10d";
      useTempPath = false;
    };
  };
}
