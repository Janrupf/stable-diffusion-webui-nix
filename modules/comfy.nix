{ lib
, config
, pkgs
, ...
}:
let
  cfg = config.services.comfyUi;
in
{
  options = {
    services.comfyUi = {
      enable = lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = ''
          Enable ComfyUI as a system service.
        '';
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "comfy-ui";
        description = ''
          User account under which the web server runs.

          ::: {.note}
          If left as the default value this user will automatically be created
          on system activation, otherwise you are responsible for
          ensuring the user exists before the service starts.
          :::
        '';
      };
      
      group = lib.mkOption {
        type = lib.types.str;
        default = "comfy-ui";
        description = ''
          Group account under which the web server runs.

          ::: {.note}
          If left as the default value this group will automatically be created
          on system activation, otherwise you are responsible for
          ensuring the user exists before the service starts.
          :::
        '';
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/comfy-ui";
        example = "/var/lib/comfy-ui";
        description = ''
          The data directory for the service.

          ::: {.note}
          If left as the default value of `/var/lib/comfy-ui` this directory will automatically be created before the web
          server starts, otherwise you are responsible for ensuring the directory exists with appropriate ownership and permissions.
          :::
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.stable-diffusion-webui.comfy.cuda;
        example = lib.literalExpression "pkgs.stable-diffusion-webui.comfy.cuda";
        description = ''
          Which package to user for the ComfyUI installation.
        '';
      };

      listenHost = lib.mkOption {
        type = lib.types.nullOr (lib.types.separatedString ",");
        description = ''
          The host address to bind the web interface to.

          :::{.note}
          Multiple addresses may be specified by separating them with a comma.
          :::
        '';
        default = null;
      };

      listenPort = lib.mkOption {
        type = lib.types.int;
        default = 8188;
        description = ''
          The port to bind the web interface to.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = lib.optionalAttrs (cfg.user == "comfy-ui") {
      comfy-ui = {
        description = "ComfyUI service user";
        group = cfg.group;
        isSystemUser = true;

        # Access to GPU for CUDA
        extraGroups = [ "video" ];
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "comfy-ui") {
      comfy-ui = {};
    };

    systemd.services.comfy-ui = {
      description = "powerful and modular diffusion model GUI";

      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      unitConfig.RequiresMountsFor = cfg.dataDir;

      script = ''
        export HF_HOME="$CACHE_DIRECTORY/huggingface/hub"

        exec ${cfg.package}/bin/comfy-ui \
          --base-directory ${lib.strings.escapeShellArg cfg.dataDir} \
          ${lib.strings.optionalString (cfg.listenHost != null) "--listen ${lib.strings.escapeShellArg cfg.listenHost}"} \
          --port ${builtins.toString cfg.listenPort}
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
          RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          PrivateMounts = true;
 
          SystemCallArchitectures = "native";
          SystemCallFilter = "@system-service";
        }
        (lib.mkIf (cfg.dataDir == "/var/lib/comfy-ui") {
          StateDirectory = "comfy-ui";
          StateDirectoryMode = "0700";

          CacheDirectory = "comfy-ui";
        })
      ];
    };
  };
}
