{ stdenv
, lib
, fetchFromGitHub
, makeWrapper
, nodejs
, yarn
, electron
, fixup_yarn_lock
, fetchYarnDeps
, symlinkJoin
}:
let

  plugins = {
    app = {
      hash = "sha256-oyshGd8FjjL4fGuKT8vqydvpNZDR5gRRGnOcCqS8dlY=";
      patch = true;
    };
    web = {
      hash = "sha256-kdER/yB8O7gfWnLZ/rNl4ha1eNnypcVmS1L7RrFCn0Q=";
      patch = true;
    };
    tabby-core = {
      hash = "sha256-5o9TZtsXRljqrek8AN/PTMK/Ev01aOE4J4nAhN1vpo4=";
    };
    tabby-settings = {
      hash = "sha256-MD0ARPbuaNo7DSNf2v5+/41EKqNDlx01A0+Qw9g650M=";
    };
    tabby-terminal = {
      hash = "sha256-p/hNIwmfDFeURKu+9Y37rf6uvbkXTiTuIgschrNEN5Y=";
      patch = true;
    };
    tabby-web = {
      hash = "sha256-ErhWM0jiVK4PBosBz4IHi1xiemAzRuk/EE8ntyhO2PE=";
    };
    tabby-community-color-schemes = {
      hash = "sha256-oZgyP0hTU9bxszOVg3Bmiu6yos2d2Inc1Do8To4z8GQ=";
    };
    tabby-ssh = {
      hash = "sha256-LJ2RbhemjblzhjKsEbdXJsEVB1ntog1Q6wOXhcdwZww=";
    };
    tabby-serial = {
      hash = "sha256-sg/CJnlkUcohFgmY6xGE79WG5mmx9jh196mb8iVCk6g=";
    };
    tabby-telnet = {
      hash = "sha256-J8nBBUxwTdigcdohEF6dw8+EHRBUm8O1SLM9oDB3VaA=";
    };
    tabby-local = {
      hash = "sha256-GmVoeKxF8Sj55fDPN4GhwGVXoktdiwF3EFYTJHGO/NQ=";
    };
    tabby-electron = {
      hash = "sha256-mwvduXvW5f7zZkTQqoUeXn3aTnFDsk3UG44GfPrt5Vw=";
    };
    tabby-plugin-manager = {
      hash = "sha256-0kw3HSJhKSezkfBRk14Ux0nGaVCzNNl1psTOxdQjLEM=";
    };
    tabby-linkifier = {
      hash = "sha256-z6I6GdZhlB36huWZ/ItcMKMDPWhpIFKkOiYvBGOhAxA=";
    };
    tabby-web-demo = {
      hash = "sha256-MCmJARigArKOge7C3EI+7zjuPFioKONmtGLni5DrirE=";
    };
  };

  # Optimize the final space taken by our derivation
  # by feeding electron builder with a tree of symlink
  # instead of real file.
  # It seem to effectively copy these symlink whenever no
  # changes are made to the file.
  symlinkedElectron = symlinkJoin {
    name = "symlinked-electron";
    paths = [ electron ];
  };

in
stdenv.mkDerivation rec {
  pname = "tabby";
  version = "1.0.197";

  src = fetchFromGitHub {
    owner = "Eugeny";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-aq6oU+PQhzbRwwBGV3AUNIp9nE1RkHWJUrTMvCJ9Cgk";
  };

  nativeBuildInputs = [ makeWrapper fixup_yarn_lock ];
  buildInputs = [ yarn nodejs ];

  patches = [ ./version.patch ];

  postPatch = ''
    substituteInPlace scripts/vars.mjs --subst-var-by VERSION "v${version}"
  '';

  rootOfflineCache = fetchYarnDeps {
    yarnLock = src + "/yarn.lock";
    hash = "sha256-AhIVzdYNisughhD2/JqWme827p766FeE5W4ivrwoQ6s=";
  };

  configurePhase = ''
    runHook preConfigure
    
    export HOME=$(mktemp -d)

    # Root yarn.lock
    yarn config --offline set yarn-offline-mirror ${rootOfflineCache}
    fixup_yarn_lock yarn.lock
    yarn install --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive
    patchShebangs node_modules/
    yarn patch-package
  '' +
  lib.concatStringsSep "\n" (lib.attrValues (lib.mapAttrs
    (plugin: value:
      let
        cache = fetchYarnDeps {
          name = "${plugin}-offline";
          yarnLock = src + "/${plugin}/yarn.lock";
          hash = value.hash;
        };
      in
      ''
        pushd ${plugin}
        yarn config --offline set yarn-offline-mirror ${cache}
        fixup_yarn_lock yarn.lock
        yarn install --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive
        patchShebangs node_modules/
      '' + lib.optionalString (value ? patch && value.patch) ''
        yarn patch-package
      '' +
      ''
        popd
        ln -fs ../${plugin} node_modules/${plugin}
      ''
    )
    plugins)) +
  ''
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    
    #node scripts/build-native.mjs
    yarn --offline electron-rebuild -f -m app -e "${symlinkedElectron}/Applications/Electron.app" -v ${electron.version} -a x86_64
  
    #node scripts/build-typings.mjs
    #node scripts/build-modules.mjs
    npm run build

    mk_electron_bundle_darwin() {
      # Darwin electron-builder pass. Same principle as below linux pass.
      # 'electron-builder' has some trouble working with RO 'plist'
      # file as input. We fix this here.
      declare nix_elec_path="$PWD/electron-dist"
      mkdir -p "$nix_elec_path"
      cp -r -t "$nix_elec_path/" "${symlinkedElectron}/Applications/Electron.app"
      chmod -R u+rw "$nix_elec_path"
      while read -s f; do
        declare fsl
        if fsl="$(readlink "$f")"; then
          cp --remove-destination "$fsl" "$f"
          chmod u+rw "$f"
        fi
      done < <(find "$nix_elec_path" -name '*.plist')

      yarn --offline electron-builder \
      --dir \
      --config electron-builder.yml \
      --macos \
      ${if stdenv.hostPlatform.isAarch64 then "--arm64" else "--x64"} \
      -c.electronDist=$nix_elec_path \
      -c.electronVersion=${electron.version} \
      -c.mac.identity=null \
      -c.extraMetadata.version=v${version}
    }
    mk_electron_bundle_linux() {
      # Linux electron-builder pass reusing existing nixpkgs electron build
      # and optimized to prevent files copies whenever possible (see '
      # symlinkedElectron').
      # Note that from what I can see to date, nothing we could not
      # easily replace without 'electron-builder'.
      # It simply:
      # -  creates an asar of the dist / build folder
      # -  rename the some electron files to our app's name
      # -  rm the existing default asar
      # -  copy its asar to the expected location
      yarn --offline electron-builder \
      --dir \
      --config electron-builder.yml \
      --linux \
      ${if stdenv.hostPlatform.isAarch64 then "--arm64" else "--x64"} \
      -c.electronDist=${symlinkedElectron}/lib/electron \
      -c.electronVersion=${electron.version} \
      -c.extraMetadata.version=v${version}
    }
    ${if stdenv.isDarwin then ''
      mk_electron_bundle_darwin
    ''
    else ''
      mk_electron_bundle_linux
    ''}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

     ${if stdenv.isDarwin then ''
      mkdir -p "$out/Applications"
      mv "$PWD/dist/mac/Tabby.app" "$out/Applications"
      wrapProgram "$out/Applications/Tabby.app/Contents/MacOS/Tabby" --add-flags "'$out/Applications/Tabby.app/Contents/Resources/app.asar'"
    ''
    else ''
      
    ''}

    # resources
    #mkdir -p "$out/share/tabby"
    #cp -r '.' "$out/share/tabby/electron"
    #rm -rf "$out/share/element/electron/node_modules"
    #cp -r './node_modules' "$out/share/element/electron"

    ## icons
    #for icon in $out/share/element/electron/build/icons/*.png; do
    #  mkdir -p "$out/share/icons/hicolor/$(basename $icon .png)/apps"
    #  ln -s "$icon" "$out/share/icons/hicolor/$(basename $icon .png)/apps/element.png"
    #done

    ## desktop item
    #mkdir -p "$out/share"
    #ln -s "{finalAttrs.desktopItem}/share/applications" "$out/share/applications"

    ## executable wrapper
    #makeWrapper '${electron}/bin/electron' "$out/bin/{executableName}" \
    #  --set LD_PRELOAD {sqlcipher}/lib/libsqlcipher.so \
    #  --add-flags "$out/share/element/electron" \
    #  --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "A terminal for a more modern age";
    homepage = "https://tabby.sh/";
    changelog = "https://github.com/Eugeny/tabby/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ Intuinewin ];
    platforms = platforms.unix;
  };
}
