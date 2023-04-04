{ config, lib, pkgs, ... }:
let
  settingsFormat = pkgs.formats.yaml { };
  cfg = config.services.warpgate;
in
{
  options.services.warpgate = {
    enable = lib.mkEnableOption (lib.mdDoc "Warpgate: smart SSH, HTTPS and MySQL bastion that needs no client-side software");

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc "Whether to enable debug logging";
    };

    settings = lib.mkOption {
      default = { };
      description = lib.mdDoc "Configuration for Warpgate";
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
        options = {
          external_host = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = lib.mdDoc "Warpgate instance external host";
          };
          database_url = lib.mkOption {
            type = lib.types.str;
            default = "sqlite:/var/lib/warpgate/db";
            description = lib.mdDoc "Database URL";
          };
          config_provider = lib.mkOption {
            type = lib.types.enum [ "database" "file" ];
            default = "database";
            description = lib.mdDoc ''
              Config Provider. If you use the mysql lite database, you'll need to intialize the admin password with the cli.
              On the other hand, if you use the config file, you'll be unable to update it from the web client and you'll need to update
              your nix configuration.
            '';
          };
          sso_providers = lib.mkOption {
            default = [ ];
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    default = "";
                    description = lib.mdDoc "SSO Name";
                  };
                  label = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = lib.mdDoc "SSO Warpgate Label";
                  };
                  provider = lib.mkOption {
                    type = lib.types.enum [
                      (lib.types.submodule {
                        options = {
                          google = lib.mkOption {
                            default = { };
                            type = lib.types.submodule {
                              options = {
                                client_id = lib.mkOption {
                                  type = lib.types.str;
                                  description = lib.mdDoc "Google client ID";
                                };
                                client_secret = lib.mkOption {
                                  type = lib.types.str;
                                  description = lib.mdDoc "Google client secret";
                                };
                              };
                            };
                          };
                        };
                      })
                      (lib.types.submodule {
                        options = {
                          apple = lib.mkOption {
                            default = { };
                            type = lib.types.submodule {
                              options = {
                                client_id = lib.mkOption {
                                  type = lib.types.str;
                                  description = lib.mdDoc "Apple client ID";
                                };
                                client_secret = lib.mkOption {
                                  type = lib.types.str;
                                  description = lib.mdDoc "Apple client secret";
                                };
                                key_id = lib.mkOption {
                                  type = lib.types.str;
                                  description = lib.mdDoc "Apple key ID";
                                };
                                team_id = lib.mkOption {
                                  type = lib.types.str;
                                  description = lib.mdDoc "Apple team ID";
                                };
                              };
                            };
                          };
                        };
                      })
                      (lib.types.submodule {
                        options = {
                          azure = lib.mkOption {
                            default = { };
                            type = lib.types.submodule {
                              options = {
                                client_id = lib.mkOption {
                                  type = lib.types.str;
                                  description = lib.mdDoc "Azure client ID";
                                };
                                client_secret = lib.mkOption {
                                  type = lib.types.str;
                                  description = lib.mdDoc "Azure client secret";
                                };
                                tenant = lib.mkOption {
                                  type = lib.types.str;
                                  description = lib.mdDoc "Azure tenant";
                                };
                              };
                            };
                          };
                        };
                      })
                      (lib.types.submodule {
                        options = {
                          custom = lib.mkOption {
                            default = { };
                            type = lib.types.submodule {
                              options = {
                                client_id = lib.mkOption {
                                  type = lib.types.str;
                                  description = lib.mdDoc "Custom client ID";
                                };
                                client_secret = lib.mkOption {
                                  type = lib.types.str;
                                  description = lib.mdDoc "Custom client secret";
                                };
                                issuer_url = lib.mkOption {
                                  type = lib.types.str;
                                  description = lib.mdDoc "Custom Issuer URL";
                                };
                                scopes = lib.mkOption {
                                  type = lib.types.listOf lib.types.str;
                                  default = [ ];
                                  description = lib.mdDoc "OIDC Scopes";
                                };
                              };
                            };
                          };
                        };
                      })
                    ];
                    default = { };
                    description = lib.mdDoc "SSO Internal provider config";
                  };
                };
              }
            );
            description = lib.mdDoc "Warpgate SSO Configurations";
          };
          ssh = lib.mkOption {
            default = { };
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = lib.mdDoc "Whether to enable Wargate SSH";
                };
                listen = lib.mkOption {
                  type = lib.types.str;
                  default = "0.0.0.0:2222";
                  description = lib.mdDoc "SSH listening endpoint";
                };
                keys = lib.mkOption {
                  type = lib.types.path;
                  default = "/var/lib/warpgate/ssh-keys";
                  description = lib.mdDoc "Directory where Warpgate client keys will be stored";
                };
                host_key_verification = lib.mkOption {
                  type = lib.types.enum [ "prompt" "auto_accept" "auto_reject" ];
                  default = "prompt";
                  description = lib.mdDoc "Handling of unknown host keys";
                };
              };
            };
            description = lib.mdDoc "Warpgate SSH Configuration";
          };
          http = lib.mkOption {
            default = { };
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = lib.mdDoc "Whether to enable Wargate HTTP";
                };
                listen = lib.mkOption {
                  type = lib.types.str;
                  default = "0.0.0.0:8888";
                  description = lib.mdDoc "HTTP listening endpoint";
                };
                certificate = lib.mkOption {
                  type = lib.types.path;
                  default = "/var/lib/warpgate/tls.certificate.pem";
                  description = lib.mdDoc "TLS Certificate, must exist if HTTP is enabled";
                };
                key = lib.mkOption {
                  type = lib.types.path;
                  default = "/var/lib/warpgate/tls.key.pem";
                  description = lib.mdDoc "TLS Private key, must exist if HTTP is enabled";
                };
              };
            };
            description = lib.mdDoc "Warpgate HTTP Configuration";
          };
          mysql = lib.mkOption {
            default = { };
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = lib.mdDoc "Whether to enable Wargate MySQL";
                };
                listen = lib.mkOption {
                  type = lib.types.str;
                  default = "0.0.0.0:33306";
                  description = lib.mdDoc "MySQL listening endpoint";
                };
                certificate = lib.mkOption {
                  type = lib.types.path;
                  default = "/var/lib/warpgate/tls.certificate.pem";
                  description = lib.mdDoc "TLS Certificate, must exist if MySQL is enabled";
                };
                key = lib.mkOption {
                  type = lib.types.path;
                  default = "/var/lib/warpgate/tls.key.pem";
                  description = lib.mdDoc "TLS Private key, must exist if MySQL is enabled";
                };
              };
            };
            description = lib.mdDoc "Warpgate MySQL Configuration";
          };
          log = lib.mkOption {
            default = { };
            type = lib.types.submodule {
              options = {
                rentention = lib.mkOption {
                  type = lib.types.str;
                  default = "7days";
                  description = lib.mdDoc "Logs retention duration";
                };
                send_to = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = lib.mdDoc "UDP socket to forward logs";
                };
              };
            };
            description = lib.mdDoc "Warpgate Logs Configuration";
          };
          recordings = lib.mkOption {
            default = { };
            type = lib.types.submodule {
              options = {
                enable = lib.mkEnableOption (lib.mdDoc "Enable Wargate recordings");
                path = lib.mkOption {
                  type = lib.types.path;
                  default = "/var/lib/warpgate/recordings";
                  description = lib.mdDoc "Directory where Warpgate recordings will be stored";
                };
              };
            };
            description = lib.mdDoc "Warpgate Recordings Configuration";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.warpgate ];

    environment.etc."warpgate/warpgate.yaml" = {
      mode = "0600";
      source = settingsFormat.generate "warpgate.yaml" cfg.settings;
    };

    systemd.services.warpgate = {
      description = "Warpgate";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "notify";
        ExecStart = "${pkgs.warpgate}/bin/warpgate --config /etc/warpgate/warpgate.yaml ${lib.optionalString cfg.debug "-d"} run";
        Restart = "always";
        RestartSec = "5s";
      };
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
    };
  };
}
