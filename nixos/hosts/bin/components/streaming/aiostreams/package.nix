{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_11,
  nodejs_24,
  python3,
  makeWrapper,
  node-gyp,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "aiostreams";
  version = "2.38.1";

  src = fetchFromGitHub {
    owner = "Viren070";
    repo = "AIOStreams";
    tag = "v${finalAttrs.version}";
    hash = "sha256-p0BCG5bZHVa6CPJ95BcooQThy31AgeL3ypjRyfyLK+w=";
  };

  pnpmWorkspaces = [
    "aiostreams"
    "@aiostreams/crypto"
    "@aiostreams/core"
    "@aiostreams/server"
    "@aiostreams/frontend"
    "@aiostreams/ui"
    "@aiostreams/web"
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src pnpmWorkspaces;
    pnpm = pnpm_11;
    fetcherVersion = 5;
    hash = "sha256-vbMhn8IPdVeE5KjcjB/HeLvjcJes8BuzW9zb80vGZOY=";
  };

  nativeBuildInputs = [
    nodejs_24
    pnpm_11
    (pnpmConfigHook.override { pnpm = pnpm_11; })
    python3
    makeWrapper
    node-gyp
  ];

  env.npm_config_nodedir = nodejs_24;

  postPatch = ''
    substituteInPlace packages/server/src/server.ts \
      --replace-fail "app.listen(appConfig.bootstrap.port," "app.listen({ fd: 3 },"
    echo '{"version":"${finalAttrs.version}","description":"","tag":"v${finalAttrs.version}","channel":"stable","commitHash":"unknown","buildTime":"1970-01-01T00:00:00.000Z","commitTime":"1970-01-01T00:00:00.000Z"}' > resources/metadata.json
  '';

  buildPhase = ''
    runHook preBuild
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    rm -rf node_modules packages/*/node_modules
    pnpm install --offline --frozen-lockfile --prod --ignore-scripts --filter=aiostreams --filter=@aiostreams/core --filter=@aiostreams/server --filter=@aiostreams/crypto
    (cd node_modules/.pnpm/yencode@*/node_modules/yencode && node-gyp rebuild)
    d=$out/lib/aiostreams
    mkdir -p $d/packages/core $d/packages/server $d/packages/frontend $d/packages/web $out/bin
    cp -r package.json node_modules resources scripts $d/
    cp -r packages/crypto $d/packages/
    cp -r packages/core/package.json packages/core/dist packages/core/node_modules $d/packages/core/
    cp -r packages/server/package.json packages/server/dist packages/server/node_modules $d/packages/server/
    cp -r packages/server/src/static $d/packages/server/dist/static
    cp -r packages/frontend/dist $d/packages/frontend/
    cp -r packages/web/dist $d/packages/web/
    rm -rf $d/packages/crypto/node_modules $d/packages/crypto/src
    makeWrapper ${lib.getExe nodejs_24} $out/bin/aiostreams \
      --add-flags "--max-semi-space-size=8 --expose-gc $d/packages/server/dist/server.js"
    runHook postInstall
  '';
})
