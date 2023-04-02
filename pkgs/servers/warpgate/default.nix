{ lib
, stdenv
, rustPlatform
, pkgs
, darwin
}:
# In order to compile the generated api clients, the version of ts used is hardcoded in the scripts section of the main package.json.
# https://github.com/warp-tech/warpgate/blob/main/warpgate-web/package.json#L14
# If this version is updated, you must update the package.json accordingly and relaunch node2nix using this command
# nix run nixpkgs#nodePackages.node2nix -- -i package.json -c /dev/null -d
let
  pname = "warpgate";
  version = "0.7.1";
  openApiGeneratorCliVersion = "5.4.0"; # See openapitools.json

  # Needed to generate api clients
  openApiGeneratorCli = pkgs.fetchurl {
    url = "https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/${openApiGeneratorCliVersion}/openapi-generator-cli-${openApiGeneratorCliVersion}.jar";
    hash = "sha256-8+0xIxDjkDJLM7ov//KQzoEpNSB6FJPsXAmNCkQb5Rw=";
  };

  # Needed to compile api clients
  nodeEnv = import ./node-env.nix {
    inherit (pkgs) nodejs stdenv lib python2 runCommand writeTextFile writeShellScript;
    inherit pkgs;
    libtool = if stdenv.isDarwin then pkgs.darwin.cctools else null;
  };
  nodePackages = import ./node-packages.nix {
    inherit (pkgs) fetchurl nix-gitignore stdenv lib fetchgit;
    inherit nodeEnv;
  };

in
rustPlatform.buildRustPackage rec {
  inherit pname version;

  src = pkgs.fetchFromGitHub {
    owner = "warp-tech";
    repo = "warpgate";
    rev = "v${version}";
    hash = "sha256-mc5Xa1ir8ypjg2e9vNczGa4YngyCIYMPcJnbdrmhtww=";
  };

  RUSTC_BOOTSTRAP = 1;
  RUSTFLAGS = "--cfg tokio_unstable";

  cargoSha256 = "sha256-JJWLcW1DIJVXags5lFWdwx1yjDMAGoFAw6yGcWiCssY=";

  offlineCache = pkgs.fetchYarnDeps {
    yarnLock = "${src}/warpgate-web/yarn.lock";
    hash = "sha256-TAYQkdoaOwNHWayLSwpqjWqGwyw5fJ22aRXRIozeh4o=";
  };

  nativeBuildInputs = with pkgs; [ pkg-config yarn nodejs jq fixup_yarn_lock jre ];

  buildInputs = with pkgs; [ openssl ]
    ++ lib.optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [ CoreServices Security ]);

  OPENSSL_NO_VENDOR = 1;

  # Cargo.lock is outdated
  preConfigure = ''
    cargo update --offline
  '';

  configurePhase = ''
    runHook preConfigure

    pushd warpgate-web

    # Yarn
    export HOME=$(mktemp -d)
    fixup_yarn_lock yarn.lock
    yarn config --offline set yarn-offline-mirror "${offlineCache}"
    yarn install --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive
    patchShebangs node_modules

    # OpenApiGenerator
    mkdir -p "node_modules/@openapitools/openapi-generator-cli/versions"
    ln -sf "${openApiGeneratorCli}" "node_modules/@openapitools/openapi-generator-cli/versions/${openApiGeneratorCliVersion}.jar"

    popd

    runHook postConfigure
  '';

  buildPhase = ''
    pushd warpgate-web

    if [ "${openApiGeneratorCliVersion}" != "$(cat openapitools.json | jq -r '."generator-cli".version')" ]; then
      echo "Mismatching version please update openapi-generator-cli in derivation"
      exit
    fi

    # Generate and compile api clients
    yarn --offline run openapi-generator-cli generate -g typescript-fetch -i src/gateway/lib/openapi-schema.json -o src/gateway/lib/api-client -p npmName=warpgate-gateway-api-client -p useSingleRequestParameter=true

    pushd src/gateway/lib/api-client
    ln -sf "${nodePackages.nodeDependencies}/lib/node_modules" node_modules
    yarn --offline tsc --target esnext --module esnext
    rm -rf src tsconfig.json
    popd

    yarn --offline run openapi-generator-cli generate -g typescript-fetch -i src/admin/lib/openapi-schema.json -o src/admin/lib/api-client -p npmName=warpgate-admin-api-client -p useSingleRequestParameter=true

    pushd src/admin/lib/api-client
    ln -sf "${nodePackages.nodeDependencies}/lib/node_modules" node_modules
    yarn --offline tsc --target esnext --module esnext
    rm -rf src tsconfig.json
    popd

    # Build website
    yarn --offline build

    popd

    cargoBuildHook
  '';

  cargoTestFlags = [ "--workspace" ];

  meta = with lib; {
    description = "Smart SSH, HTTPS and MySQL bastion that needs no client-side software";
    homepage = "https://github.com/warp-tech/warpgate";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
