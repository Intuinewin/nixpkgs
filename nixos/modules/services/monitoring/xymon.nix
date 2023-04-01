{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.xymon;

  xymonServerConfig = pkgs.writeTextFile {
    name = "xymonserver.cfg";
    text = ''
      XYMONSERVERROOT="${cfg.dataDir}"
      XYMONHOME="${cfg.dataDir}/server"
      XYMONVAR="${cfg.dataDir}/data"
      XYMONTMP="/tmp/xymon"
      XYMONSERVERHOSTNAME="${cfg.serverHostname}"
      XYMONSERVERIP="${cfg.serverIp}"
      XYMONSERVERLOGS="${cfg.logDir}"
      HOSTSCFG="${xymonHostsConfig}"
      HOSTSCFG="${xymonHostsConfig}"
      FPING="${pkgs.xymon}/usr/lib/xymon/server/bin/xymonping"
      ${cfg.extraConfig}
    '';
  };

  xymonHostsConfig = pkgs.writeTextFile {
    name = "hosts.cfg";
    text = cfg.hostsFile;
  };

  xymonTasksConfig = pkgs.writeTextFile {
    name = "tasks.cfg";
    text = ''
      #
      # The tasks.cfg file is loaded by "xymonlaunch".
      # It controls which of the Xymon modules to run, how often, and
      # with which parameters, options and environment variables.
      #
      
      ######################################################################################
      ### 
      ### xymond master daemon and worker modules below.
      ### You definitely need these on a Xymon server.
      ### 
      ######################################################################################
      
      # This is the main Xymon daemon. This must be running on at least
      # one server in your setup. If you are setting up a server to do
      # just network tests or run xymonproxy, it is OK to disable this (then
      # you also need to remove the "NEEDS xymond" lines for the tasks
      # you want to run).
      [xymond]
      	ENVFILE ${xymonServerConfig}
      	CMD ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond --pidfile=/run/xymon/xymond.pid \
      		--restart=$XYMONTMP/xymond.chk --checkpoint-file=$XYMONTMP/xymond.chk --checkpoint-interval=600 \
      		--log=$XYMONSERVERLOGS/xymond.log \
      		--admin-senders=127.0.0.1,$XYMONSERVERIP \
      		--store-clientlogs=!msgs
      
      # "history" keeps track of the status changes that happen.
      [history]
      	ENVFILE ${xymonServerConfig}
      	NEEDS xymond
      	CMD ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond_channel --channel=stachg --log=$XYMONSERVERLOGS/history.log ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond_history --pidfile=/run/xymon/xymond_history.pid
      
      # "alert" sends out alerts.
      [alert]
      	ENVFILE ${xymonServerConfig}
      	NEEDS xymond
      	CMD ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond_channel --channel=page  --log=$XYMONSERVERLOGS/alert.log ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond_alert --checkpoint-file=$XYMONTMP/alert.chk --checkpoint-interval=600
      
      # The client back-end module. You need this if you are running the Xymon client on any system.
      [clientdata]
      	ENVFILE ${xymonServerConfig}
      	NEEDS xymond
      	CMD ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond_channel --channel=client --log=$XYMONSERVERLOGS/clientdata.log ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond_client
      
      # "rrdstatus" updates RRD files with information that arrives as "status" messages.
      [rrdstatus]
      	ENVFILE ${xymonServerConfig}
      	NEEDS xymond
      	CMD ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond_channel --channel=status --log=$XYMONSERVERLOGS/rrd-status.log ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond_rrd --rrddir=$XYMONVAR/rrd
      
      # "rrddata" updates RRD files with information that arrives as "data" messages.
      [rrddata]
      	ENVFILE ${xymonServerConfig}
      	NEEDS xymond
      	CMD ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond_channel --channel=data --log=$XYMONSERVERLOGS/rrd-data.log ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond_rrd --rrddir=$XYMONVAR/rrd
      
      # "hostdata" stores the Xymon client messages on disk when some status for a host
      # changes. This lets you access a lot of data collected from a host around the time
      # when a problem occurred. However, it may use a significant amount of disk space
      # if you have lots of Xymon clients.
      # Note: The --store-clientlogs option for the [xymond] provides control over
      #       which status-changes will cause a client message to be stored.
      [hostdata]
      	ENVFILE ${xymonServerConfig}
      	NEEDS xymond
      	CMD ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond_channel --channel=clichg --log=$XYMONSERVERLOGS/hostdata.log ${pkgs.xymon}/usr/lib/xymon/server/bin/xymond_hostdata
      
      
      ######################################################################################
      ### 
      ### Xymon generator for the overview web-pages.
      ### 
      ######################################################################################
      
      # "xymongen" runs the xymongen tool to generate the Xymon webpages from the status information that
      # has been received.
      [xymongen]
      	ENVFILE ${xymonServerConfig}
      	NEEDS xymond
      	GROUP generators
      	CMD ${pkgs.xymon}/usr/lib/xymon/server/bin/xymongen $XYMONGENOPTS --report
      	LOGFILE $XYMONSERVERLOGS/xymongen.log
      	INTERVAL 1m
      
      
      ######################################################################################
      ### 
      ### Xymon network tests
      ### 
      ######################################################################################
      
      # "xymonnet" runs the xymonnet tool to perform the network based tests - i.e. http, smtp, ssh, dns and
      # all of the various network protocols we need to test.
      [xymonnet]
      	ENVFILE ${xymonServerConfig}
      	NEEDS xymond
      	CMD ${pkgs.xymon}/usr/lib/xymon/server/bin/xymonnet --report --ping --checkresponse
      	LOGFILE $XYMONSERVERLOGS/xymonnet.log
      	INTERVAL 5m
      
      # "xymonnetagain" picks up the tests that the normal network test consider "failed", and re-does those
      # tests more often. This enables Xymon to pick up a recovered network service faster than
      # if it were tested only by the "xymonnet" task (which only runs every 5 minutes). So if you have
      # servers with very high availability guarantees, running this task will make your availability
      # reports look much better.
      [xymonnetagain]
      	ENVFILE ${xymonServerConfig}
      	NEEDS xymond
      	CMD $XYMONHOME/ext/xymonnet-again.sh
      	LOGFILE $XYMONSERVERLOGS/xymonnetagain.log
      	INTERVAL 1m
      
      
      
      ######################################################################################
      ### 
      ### Miscellaneous Xymon modules
      ### 
      ######################################################################################
      
      # combostatus is an extension script for the Xymon display server. It generates
      # status messages that are combined from the status of one or more normal statuses.
      # It is controlled via the combo.cfg file.
      [combostatus]
      	ENVFILE ${xymonServerConfig}
      	NEEDS xymond
      	CMD ${pkgs.xymon}/usr/lib/xymon/server/bin/combostatus
      	LOGFILE $XYMONSERVERLOGS/combostatus.log
      	INTERVAL 5m
      
      
      ######################################################################################
      ### 
      ### Xymon client for monitoring the Xymon server itself.
      ### 
      ######################################################################################
      
      # "xymonclient" runs the Xymon client. The client is installed automatically
      # when you install a Xymon server (presumably, you do want to monitor the 
      # Xymon server ?), but there's no need to have two xymonlaunch instances
      # running at the same time. So we'll just run it from here.
      [xymonclient]
      	ENVFILE ${xymonServerConfig}
      	NEEDS xymond
      	CMD ${pkgs.xymon}/usr/lib/xymon/client/bin/xymonclient.sh
      	LOGFILE $XYMONSERVERLOGS/xymonclient.log
      	INTERVAL 5m
      
      ${cfg.extraTasks}
    '';
  };
in
{
  options.services.xymon = {
    enable = mkEnableOption (lib.mdDoc "xymon");

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/xymon";
      description = lib.mdDoc "State directory for the xymon service.";
    };

    serverHostname = mkOption {
      type = types.str;
      default = "localhost";
      description = lib.mdDoc "Server Hostname";
    };

    serverIp = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = lib.mdDoc "Address to bind to. The default is to bind to all addresses";
    };

    logDir = mkOption {
      type = types.path;
      description = lib.mdDoc "Location where the logfiles are stored";
      default = "/var/log/xymon";
    };

    extraConfig = mkOption {
      description = lib.mdDoc "These lines go into xymonserver.cfg verbatim.";
      default = "";
      type = types.lines;
    };

    extraTasks = mkOption {
      description = lib.mdDoc "These lines go into tasks.cfg verbatim.";
      default = "";
      type = types.lines;
    };

    hostsFile = mkOption {
      description = lib.mdDoc "These lines go into hosts.cfg verbatim.";
      default = "";
      type = types.lines;
    };

    comboFile = mkOption {
      description = lib.mdDoc "These lines go into combo.cfg verbatim.";
      default = "";
      type = types.lines;
    };

    protocolsFile = mkOption {
      description = lib.mdDoc "These lines go into protocols.cfg verbatim.";
      default = "";
      type = types.lines;
    };

    analysisFile = mkOption {
      description = lib.mdDoc "These lines go into analysis.cfg verbatim.";
      default = "";
      type = types.lines;
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Whether to run xymon in debug mode.";
    };

    verbose = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Whether to run xymon in verbose mode.";
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.logDir}' - xymon xymon - -"
    ];

    systemd.services.xymond = {
      description = "Xymon Monitoring System";
      wantedBy = [ "multi-user.target" ];
      after = [ "networking.target" ];
      serviceConfig = {
        ExecStart = ''
          ${pkgs.xymon}/usr/lib/xymon/server/bin/xymoncmd \
            ${pkgs.xymon}/usr/lib/xymon/server/bin/xymonlaunch \
              --no-daemon \
              --env=${xymonServerConfig} \
              --log=${cfg.logDir}/xymonlaunch.log \
              --config=${xymonTasksConfig} \
              ${optionalString cfg.debug "--debug"} \
              ${optionalString cfg.verbose "--verbose"}
        '';
        User = "xymon";
        Group = "xymon";
      };

      # The xymon server needs access to a bunch of files at runtime that
      # are not created automatically at server startup; they're meant to be
      # installed in $PREFIX/var/lib/xymon by `make install`. And those
      # files need to be writeable, so we can't just point at the ones in the
      # nix store. Instead we take the approach of copying them out of the store
      # on first run. If `xymon` already exists, we assume the rest of the
      # files do as well, and copy nothing -- otherwise we risk ovewriting
      # server state information every time the server is upgraded.
      preStart = ''
        ${pkgs.coreutils}/bin/mkdir -p /tmp/xymon "${cfg.dataDir}/server/bin" "${cfg.dataDir}/data"
        for file in "${pkgs.xymon}/usr/lib/xymon/{server,client}/bin/*"; do
          ln -sf "$file" "${cfg.dataDir}/server/bin/$(basename \"$file\")"
        done
        ln -sf "${pkgs.xymon}/usr/lib/xymon/server/ext" "${cfg.dataDir}/server/ext"
        ln -sf "${pkgs.xymon}/etc/xymon/web" "${cfg.dataDir}/server/web"
        ln -sf "${pkgs.xymon}/var/lib/xymon/www" "${cfg.dataDir}/server/www"

        ${pkgs.coreutils}/bin/mkdir -p "${cfg.dataDir}/data/acks"

        echo "${cfg.comboFile}" > "${cfg.dataDir}/server/etc/combo.cfg"
        echo "${cfg.protocolsFile}" > "${cfg.dataDir}/server/etc/protocols.cfg"
        echo "${cfg.analysisFile}" > "${cfg.dataDir}/server/etc/analysis.cfg"

        #if [ ! -e "${cfg.dataDir}/server" ]; then
        #  ${pkgs.rsync}/bin/rsync -a --chmod=u=rwX,go=rX \
        #    "${pkgs.xymon}/var/lib/xymon/" "${cfg.dataDir}/server/"
        #fi
        #${pkgs.coreutils}/bin/mkdir -p /tmp/xymon "${cfg.dataDir}/server/etc"
      '';
    };

    users.users.xymon = {
      uid = config.ids.uids.xymon;
      group = "xymon";
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.xymon = {
      gid = config.ids.gids.xymon;
    };
  };
}
