{ lib, stdenv, gnumake, fetchsvn, c-ares, libtirpc, openssl, pcre, rrdtool }:

stdenv.mkDerivation rec {
  version = "4.3.30";
  pname = "xymon-client";

  src = fetchsvn {
    url = "svn://svn.code.sf.net/p/xymon/code/branches/${version}";
    sha256 = "sha256-QNg9PmeqTb7lGnYkxBkKD9ZZpRT252kdiIE/17MbMLM=";
  };

  buildInputs = [
    c-ares
    libtirpc
    gnumake
    openssl
    pcre
    rrdtool
  ];

  env.NIX_CFLAGS_COMPILE = toString [ "-I${libtirpc.dev}/include/tirpc" ];

  configurePhase = ''
    USEXYMONPING=y \
    ENABLESSL=y \
    ENABLELDAP=y \
    ENABLELDAPSSL=y \
    XYMONUSER=xymon \
    XYMONTOPDIR=/ \
    XYMONVAR=/var/lib/xymon \
    XYMONHOSTURL=/xymon \
    CGIDIR=/usr/lib/xymon/cgi-bin \
    XYMONCGIURL=/xymon-cgi \
    SECURECGIDIR=/usr/lib/xymon/cgi-secure \
    SECUREXYMONCGIURL=/xymon-seccgi \
    HTTPDGID=www-data \
    XYMONLOGDIR=/var/log/xymon \
    XYMONHOSTNAME=localhost \
    XYMONHOSTIP=127.0.0.1 \
    MANROOT=/usr/share/man \
    INSTALLBINDIR=/usr/lib/xymon/server/bin \
    INSTALLETCDIR=/etc/xymon \
    INSTALLWEBDIR=/etc/xymon/web \
    INSTALLEXTDIR=/usr/lib/xymon/server/ext \
    INSTALLTMPDIR=/var/lib/xymon/tmp \
    INSTALLWWWDIR=/var/lib/xymon/www \
    ./configure --client
  '';

  makeFlags = [
    "INSTALLROOT=$(out)"
    "PKGBUILD=1"
  ];

  buildTargets = "client";
  installTargets = "client-install";

  meta = with lib; {
    description = "Hosts and Networks monitoring tool.";
    homepage = "https://xymon.sourceforge.io/";
    license = licenses.gpl2Plus;
    platforms = platforms.unix;
    maintainers = [ ];
    mainProgram = "xymon";
  };
}
