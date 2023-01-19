{ self }:
{ pkgs, config, lib, ... }:

let
  cfg = config.services.mastodon_prom_exporter;
in
{
  options.services.mastodon_prom_exporter = {
    enable = lib.mkEnableOption "Enables mastodon_prom_exporter";

    host = lib.mkOption {
      type = lib.types.str;
      example = "https://mastodon.social";
      description = "Which mastodon instance to query for stats";
    };

    port = lib.mkOption rec {
      type = lib.types.port;
      default = 9020;
      example = default;
      description = "Port on which to bind the exporter";
    };
    
  };

  config = lib.mkIf cfg.enable {
    systemd.services."prometheus-mastodon-exporter" = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = let
        binding = "0.0.0.0:${toString cfg.port}";
        pkg = self.packages.${pkgs.system}.default;
      in
        with lib; {
          ExecStart = "${pkg}/bin/mastodon_prom_exporter --host ${cfg.host} --bind ${binding}";
          Restart = mkDefault "always";
          PrivateTmp = mkDefault true;
          WorkingDirectory = mkDefault /tmp;
          DynamicUser = true;
          # Hardening
          CapabilityBoundingSet = mkDefault [ "" ];
          DeviceAllow = [ "" ];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = mkDefault true;
          ProtectClock = mkDefault true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectSystem = mkDefault "strict";
          RemoveIPC = true;
          RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          UMask = "0077";
        };
    };
  };
}
