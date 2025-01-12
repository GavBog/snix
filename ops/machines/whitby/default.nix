{ depot, lib, pkgs, ... }: # readTree options
{ config, ... }: # passed by module system

let
  inherit (builtins) listToAttrs;
  inherit (lib) range;

  mod = name: depot.path.origSrc + ("/ops/modules/" + name);
in
{
  imports = [
    (mod "atward.nix")
    (mod "builderball.nix")
    (mod "cgit.nix")
    (mod "cheddar.nix")
    (mod "clbot.nix")
    (mod "gerrit-autosubmit.nix")
    (mod "harmonia.nix")
    (mod "irccat.nix")
    (mod "josh.nix")
    (mod "journaldriver.nix")
    (mod "known-hosts.nix")
    (mod "livegrep.nix")
    (mod "monorepo-gerrit.nix")
    (mod "owothia.nix")
    (mod "panettone.nix")
    (mod "paroxysm.nix")
    (mod "restic.nix")
    (mod "smtprelay.nix")
    (mod "teleirc.nix")
    (mod "tvl-buildkite.nix")
    (mod "tvl-slapd/default.nix")
    (mod "tvl-users.nix")
    (mod "www/atward.tvl.fyi.nix")
    (mod "www/auth.tvl.fyi.nix")
    (mod "www/b.tvl.fyi.nix")
    (mod "www/cache.tvl.fyi.nix")
    (mod "www/cache.tvl.su.nix")
    (mod "www/cl.tvl.fyi.nix")
    (mod "www/code.tvl.fyi.nix")
    (mod "www/cs.tvl.fyi.nix")
    (mod "www/deploys.tvl.fyi.nix")
    (mod "www/self-cache.tvl.fyi.nix")
    (mod "www/self-redirect.nix")
    (mod "www/signup.tvl.fyi.nix")
    (mod "www/static.tvl.fyi.nix")
    (mod "www/status.tvl.su.nix")
    (mod "www/todo.tvl.fyi.nix")
    (mod "www/tvix.dev.nix")
    (mod "www/tvl.fyi.nix")
    (mod "www/tvl.su.nix")
    (mod "www/wigglydonke.rs.nix")

    # experimental!
    (mod "www/grep.tvl.fyi.nix")

    (depot.third_party.agenix.src + "/modules/age.nix")
  ];

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
  };

  boot = {
    tmp.useTmpfs = true;
    kernelModules = [ "kvm-amd" ];
    supportedFilesystems = [ "zfs" ];

    initrd = {
      availableKernelModules = [
        "igb"
        "xhci_pci"
        "nvme"
        "ahci"
        "usbhid"
        "usb_storage"
        "sr_mod"
      ];

      # Enable SSH in the initrd so that we can enter disk encryption
      # passwords remotely.
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 2222;
          authorizedKeys =
            depot.users.tazjin.keys.all
            ++ depot.users.lukegb.keys.all
            ++ [ depot.users.aspen.keys.whitby ];

          hostKeys = [
            /etc/secrets/initrd_host_ed25519_key
          ];
        };

        # this will launch the zfs password prompt on login and kill the
        # other prompt
        postCommands = ''
          echo "zfs load-key -a && killall zfs" >> /root/.profile
        '';
      };
    };

    kernel.sysctl = {
      "net.ipv4.tcp_congestion_control" = "bbr";
    };

    loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "/dev/disk/by-id/nvme-SAMSUNG_MZQLB1T9HAJR-00007_S439NA0N201620";
    };

    zfs.requestEncryptionCredentials = true;
  };

  fileSystems = {
    "/" = {
      device = "zroot/root";
      fsType = "zfs";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/073E-7FBD";
      fsType = "vfat";
    };

    "/nix" = {
      device = "zroot/nix";
      fsType = "zfs";
    };

    "/home" = {
      device = "zroot/home";
      fsType = "zfs";
    };
  };

  networking = {
    # Glass is boring, but Luke doesn't like Wapping - the Prospect of
    # Whitby, however, is quite a pleasant establishment.
    hostName = "whitby";
    domain = "tvl.fyi";
    hostId = "b38ca543";
    useDHCP = false;

    # Don't use Hetzner's DNS servers.
    nameservers = [
      "8.8.8.8"
      "8.8.4.4"
    ];

    defaultGateway6 = {
      address = "fe80::1";
      interface = "enp196s0";
    };

    firewall.allowedTCPPorts = [ 22 80 443 4238 8443 29418 ];
    firewall.allowedUDPPorts = [ 8443 ];

    interfaces.enp196s0.useDHCP = true;
    interfaces.enp196s0.ipv6.addresses = [
      {
        address = "2a01:04f8:0242:5b21::feed:edef:beef";
        prefixLength = 64;
      }
    ];
  };

  # Generate an immutable /etc/resolv.conf from the nameserver settings
  # above (otherwise DHCP overwrites it):
  environment.etc."resolv.conf" = with lib; {
    source = pkgs.writeText "resolv.conf" ''
      ${concatStringsSep "\n" (map (ns: "nameserver ${ns}") config.networking.nameservers)}
      options edns0
    '';
  };

  # Disable background git gc system-wide, as it has a tendency to break CI.
  environment.etc."gitconfig".source = pkgs.writeText "gitconfig" ''
    [gc]
    autoDetach = false
  '';

  time.timeZone = "UTC";

  nix = {
    nrBuildUsers = 256;
    settings = {
      max-jobs = lib.mkDefault 64;
      secret-key-files = "/run/agenix/nix-cache-priv";

      trusted-users = [
        "aspen"
        "lukegb"
        "tazjin"
        "sterni"
      ];
    };

    sshServe = {
      enable = true;
      keys = with depot.users;
        tazjin.keys.all
        ++ lukegb.keys.all
        ++ [ aspen.keys.whitby ]
        ++ sterni.keys.all
      ;
    };
  };

  programs.mtr.enable = true;
  programs.mosh.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Configure secrets for services that need them.
  age.secrets =
    let
      secretFile = name: depot.ops.secrets."${name}.age";
    in
    {
      clbot.file = secretFile "clbot";
      gerrit-autosubmit.file = secretFile "gerrit-autosubmit";
      grafana.file = secretFile "grafana";
      irccat.file = secretFile "irccat";
      keycloak-db.file = secretFile "keycloak-db";
      owothia.file = secretFile "owothia";
      panettone.file = secretFile "panettone";
      smtprelay.file = secretFile "smtprelay";
      teleirc.file = secretFile "teleirc";

      nix-cache-priv = {
        file = secretFile "nix-cache-priv";
        mode = "0440";
        group = "harmonia";
      };

      buildkite-agent-token = {
        file = secretFile "buildkite-agent-token";
        mode = "0440";
        group = "buildkite-agents";
      };

      buildkite-graphql-token = {
        file = secretFile "buildkite-graphql-token";
        mode = "0440";
        group = "buildkite-agents";
      };

      buildkite-besadii-config = {
        file = secretFile "besadii";
        mode = "0440";
        group = "buildkite-agents";
      };

      buildkite-private-key = {
        file = secretFile "buildkite-ssh-private-key";
        mode = "0440";
        group = "buildkite-agents";
      };

      gerrit-besadii-config = {
        file = secretFile "besadii";
        owner = "git";
      };

      gerrit-secrets = {
        file = secretFile "gerrit-secrets";
        path = "/var/lib/gerrit/etc/secure.config";
        owner = "git";
        mode = "0400";
      };

      clbot-ssh = {
        file = secretFile "clbot-ssh";
        owner = "clbot";
      };

      # Not actually a secret
      nix-cache-pub = {
        file = secretFile "nix-cache-pub";
        mode = "0444";
      };

      depot-replica-key = {
        file = secretFile "depot-replica-key";
        mode = "0500";
        owner = "git";
        group = "git";
        path = "/var/lib/git/.ssh/id_ed25519";
      };
    };

  # Automatically collect garbage from the Nix store.
  services.depot.automatic-gc = {
    enable = true;
    interval = "1 hour";
    diskThreshold = 200; # GiB
    maxFreed = 420; # GiB
    preserveGenerations = "90d";
  };

  # Run a handful of Buildkite agents to support parallel builds.
  services.depot.buildkite = {
    enable = true;
    agentCount = 32;
  };

  # Run Markdown/code renderer
  services.depot.cheddar.enable = true;

  # Start a local SMTP relay to Gmail (used by gerrit)
  services.depot.smtprelay = {
    enable = true;
    args = {
      listen = ":2525";
      remote_host = "smtp.gmail.com:587";
      remote_auth = "plain";
      remote_user = "tvlbot@tazj.in";
    };
  };

  # Start a ZNC instance which bounces for tvlbot and owothia.
  services.znc = {
    enable = true;
    useLegacyConfig = false;
    config = {
      LoadModule = [
        "webadmin"
        "adminlog"
      ];

      User.admin = {
        Admin = true;
        Pass.password = {
          Method = "sha256";
          Hash = "bb00aa8239de484c2925b1c3f6a196fb7612633f001daa9b674f83abe7e1103f";
          Salt = "TiB0Ochb1CrtpMTl;2;j";
        };
      };

      Listener.l = {
        Host = "localhost";
        Port = 2627; # bncr
        SSL = false;
      };
    };
  };

  # Start the Gerrit->IRC bot
  services.depot.clbot = {
    enable = true;
    channels = {
      "#tvl" = { };
      "#tvix-dev" = {
        only_display = "tvix,nix-compat,third_party,third-party,3p";
      };
    };

    # See //fun/clbot for details.
    flags = {
      gerrit_host = "cl.tvl.fyi:29418";
      gerrit_ssh_auth_username = "clbot";
      gerrit_ssh_auth_key = config.age.secretsDir + "/clbot-ssh";

      irc_server = "localhost:${toString config.services.znc.config.Listener.l.Port}";
      irc_user = "tvlbot";
      irc_nick = "tvlbot";

      notify_branches = "canon,refs/meta/config";
      notify_repo = "depot";

      # This secret is read from an environment variable, which is
      # populated by a systemd EnvironmentFile.
      irc_pass = "$CLBOT_PASS";
    };
  };

  services.depot = {
    # Run a livegrep code search instance
    livegrep.enable = true;

    # Run Nix cache proxy
    builderball.enable = true;

    # Run the Panettone issue tracker
    panettone = {
      enable = true;
      dbUser = "panettone";
      dbName = "panettone";
      irccatChannel = "#tvl";
    };

    # Run the first cursed bot (quote bot)
    paroxysm.enable = true;

    # Run the second cursed bot
    owothia = {
      enable = true;
      ircServer = "localhost";
      ircPort = config.services.znc.config.Listener.l.Port;
    };

    # Run irccat to forward messages to IRC
    irccat = {
      enable = true;
      config = {
        tcp.listen = ":4722"; # "ircc"
        irc = {
          server = "localhost:${toString config.services.znc.config.Listener.l.Port}";
          tls = false;
          nick = "tvlbot";
          # Note: irccat means 'ident' where it says 'realname', so
          # this is critical for connecting to ZNC.
          realname = "tvlbot";
          channels = [
            "#tvl"
          ];
        };
      };
    };

    # Run the Telegram<>IRC bridge for Volga Sprint.
    teleirc.enable = true;

    # Run atward, the search engine redirection thing.
    atward.enable = true;

    # Run cgit & josh to serve git
    cgit = {
      enable = true;
      user = "git"; # run as the same user as gerrit
    };

    josh.enable = true;

    # Configure backups to GleSYS
    restic = {
      enable = true;
      paths = [
        "/var/backup/postgresql"
        "/var/lib/grafana"
        "/var/lib/znc"
      ];
    };

    # Run autosubmit bot for Gerrit
    gerrit-autosubmit.enable = true;
  };

  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    package = pkgs.postgresql_16;

    authentication = lib.mkForce ''
      local all all trust
      host all all 127.0.0.1/32 password
      host all all ::1/128 password
      hostnossl all all 127.0.0.1/32 password
      hostnossl all all ::1/128  password
    '';

    ensureDatabases = [
      "panettone"
    ];

    ensureUsers = [{
      name = "panettone";
      ensureDBOwnership = true;
    }];
  };

  services.postgresqlBackup = {
    enable = true;
    databases = [
      "keycloak"
      "panettone"
      "tvldb"
    ];
  };

  # Run a Harmonia binary cache.
  #
  # TODO(tazjin): switch to upstream module after fix for Nix 2.3
  services.depot.harmonia = {
    enable = true;
    signKeyPaths = [ (config.age.secretsDir + "/nix-cache-priv") ];
    settings.bind = "127.0.0.1:6443";
    settings.priority = 50;
  };

  services.fail2ban.enable = true;

  environment.systemPackages = (with pkgs; [
    bat
    bb
    curl
    direnv
    emacs-nox
    fd
    git
    htop
    hyperfine
    jq
    nano
    nvd
    ripgrep
    tree
    unzip
    vim
    zfs
    zfstools
  ]) ++ (with depot; [
    ops.deploy-whitby
  ]);

  # Required for prometheus to be able to scrape stats
  services.nginx.statusPage = true;

  # Configure Prometheus & Grafana. Exporter configuration for
  # Prometheus is inside the respective service modules.
  services.prometheus = {
    enable = true;
    retentionTime = "90d";

    exporters = {
      node = {
        enable = true;

        enabledCollectors = [
          "logind"
          "processes"
          "systemd"
        ];
      };

      nginx = {
        enable = true;
        sslVerify = false;
        constLabels = [ "host=whitby" ];
      };
    };

    scrapeConfigs = [{
      job_name = "node";
      scrape_interval = "5s";
      static_configs = [{
        targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
      }];
    }
      {
        job_name = "nginx";
        scrape_interval = "5s";
        static_configs = [{
          targets = [ "localhost:${toString config.services.prometheus.exporters.nginx.port}" ];
        }];
      }];
  };

  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_port = 4723; # "graf" on phone keyboard
        domain = "status.tvl.su";
        root_url = "https://status.tvl.su";
      };

      analytics.reporting_enabled = false;

      "auth.generic_oauth" = {
        enabled = true;
        client_id = "grafana";
        scopes = "openid profile email";
        name = "TVL";
        email_attribute_path = "mail";
        login_attribute_path = "sub";
        name_attribute_path = "displayName";
        auth_url = "https://auth.tvl.fyi/auth/realms/TVL/protocol/openid-connect/auth";
        token_url = "https://auth.tvl.fyi/auth/realms/TVL/protocol/openid-connect/token";
        api_url = "https://auth.tvl.fyi/auth/realms/TVL/protocol/openid-connect/userinfo";

        # Give lukegb, aspen, tazjin "Admin" rights.
        role_attribute_path = "((sub == 'lukegb' || sub == 'aspen' || sub == 'tazjin') && 'Admin') || 'Editor'";

        # Allow creating new Grafana accounts from OAuth accounts.
        allow_sign_up = true;
      };

      "auth.anonymous" = {
        enabled = true;
        org_name = "The Virus Lounge";
        org_role = "Viewer";
      };

      "auth.basic".enabled = false;

      auth = {
        oauth_auto_login = true;
        disable_login_form = true;
      };
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [{
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:9090";
      }];
    };
  };

  # Contains GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET.
  systemd.services.grafana.serviceConfig.EnvironmentFile = config.age.secretsDir + "/grafana";

  services.keycloak = {
    enable = true;

    settings = {
      http-port = 5925; # kycl
      hostname = "auth.tvl.fyi";
      http-relative-path = "/auth";
      proxy-headers = "xforwarded";
      http-enabled = true;
    };

    database = {
      type = "postgresql";
      passwordFile = config.age.secretsDir + "/keycloak-db";
      createLocally = false;
    };
  };

  # Join TVL Tailscale network at net.tvl.fyi
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server"; # for exit-node usage
  };

  # Allow Keycloak access to the LDAP module by forcing in the JVM
  # configuration
  systemd.services.keycloak.environment.PREPEND_JAVA_OPTS =
    "--add-exports=java.naming/com.sun.jndi.ldap=ALL-UNNAMED";

  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
    }
  ];

  users = {
    # Set up a user & group for git shenanigans
    groups.git = { };
    users.git = {
      group = "git";
      isSystemUser = true;
      createHome = true;
      home = "/var/lib/git";
    };
  };

  zramSwap.enable = true;

  # Use TVL cache locally through the proxy; for cross-builder substitution.
  tvl.cache.enable = true;
  tvl.cache.builderball = true;

  system.stateVersion = "20.03";
}
