{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (builtins) toString;
  inherit (lib)
    mkEnableOption
    mkOption
    literalExpression
    optionalAttrs
    mkIf
    ;
  inherit (lib.types)
    str
    path
    port
    package
    ;
  inherit (lib.strings) escapeShellArg optionalString;
  cfg = config.services.sd-webui-forge;
in
{
  options.services.sd-webui-forge = {
    enable = mkEnableOption "the stable diffusion Forge WebUI";

    user = mkOption {
      type = str;
      default = "sd-webui-forge";
      description = ''
        User account under which the web server runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the service starts.
        :::
      '';
    };

    group = mkOption {
      type = str;
      default = "sd-webui-forge";
      description = ''
        Group account under which the web server runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the service starts.
        :::
      '';
    };

    dataDir = mkOption {
      type = path;
      default = "/var/lib/sd-webui-forge";
      description = ''
        The data directory for the service.

        ::: {.note}
        If left as the default value of `/var/lib/sd-webui-forge` this directory will automatically be created before the web
        server starts, otherwise you are responsible for ensuring the directory exists with appropriate ownership and permissions.
        :::
      '';
    };

    package = mkOption {
      type = package;
      default = pkgs.stable-diffusion-webui.forge.cuda;
      example = literalExpression "pkgs.stable-diffusion-webui.forge.cuda";
      description = ''
        Which package to user for the ComfyUI installation.
      '';
    };

    listen = mkEnableOption "listening on 0.0.0.0";

    port = mkOption {
      type = port;
      default = 7860;
      description = ''
        The port to bind the web interface to.
      '';
    };

    extraArgs = mkOption {
      type = str;
      default = "";
      example = "--cuda-malloc --skip-load-model-at-start";
      description = "Extra CLI arguments that will be added to the sd-webui-forge command.";
    };
  };

  config = mkIf cfg.enable {
    users.users = optionalAttrs (cfg.user == "sd-webui-forge") {
      sd-webui-forge = {
        description = "sd-webui-forge service user";
        inherit (cfg) group;
        isSystemUser = true;

        # Access to GPU for CUDA
        extraGroups = [ "video" ];
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "sd-webui-forge") {
      sd-webui-forge = { };
    };

    systemd.services.sd-webui-forge = {
      description = "powerful and modular diffusion model GUI";

      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      unitConfig.RequiresMountsFor = cfg.dataDir;

      # Needed or forge will not start
      path = [ pkgs.git ];

      script = ''
        exec ${cfg.package}/bin/stable-diffusion-webui \
          --data-dir ${escapeShellArg cfg.dataDir} \
          ${optionalString cfg.listen "--listen"} \
          --port ${toString cfg.port} \
          ${cfg.extraArgs}
      '';

      serviceConfig = lib.mkMerge [
        {
          Type = "simple";
          Restart = "on-failure";
          RestartSec = "5s";

          User = cfg.user;
          Group = cfg.group;

          ReadWritePaths = [ cfg.dataDir ];

          CapabilityBoundingSet = "";
          NoNewPrivileges = true;

          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ProtectHostname = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          PrivateMounts = true;

          SystemCallArchitectures = "native";
          SystemCallFilter = "@system-service";
        }
        (lib.mkIf (cfg.dataDir == "/var/lib/sd-webui-forge") {
          StateDirectory = "sd-webui-forge";
          StateDirectoryMode = "0700";
          CacheDirectory = "sd-webui-forge";
        })
      ];
    };
  };
}
