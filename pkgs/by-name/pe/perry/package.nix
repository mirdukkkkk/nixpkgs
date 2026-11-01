{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  llvmPackages_22,
  libffi,
  libxml2,
  zlib,
  cmake,
  makeBinaryWrapper,
  versionCheckHook,
  nix-update-script,
  openssl,
  pkg-config,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "perry";
  version = "0.5.1664";

  src = fetchFromGitHub {
    owner = "PerryTS";
    repo = "perry";
    tag = "v${finalAttrs.version}";
    hash = "sha256-hZw7ht6qbvU6KxYLmAxIRibmWNffDyBRDCC5o3/27s0=";
  };

  cargoHash = "sha256-Pa0G2TKrWDIgYUNPPkU3RAUbcQRI6LTsXEjk03mMY+g=";

  nativeBuildInputs = [
    rustPlatform.bindgenHook
    llvmPackages_22.clang # perry-runtime's build.rs compiles perry_trap.ll
    cmake
    pkg-config
    makeBinaryWrapper
  ];

  buildInputs = [
    llvmPackages_22.llvm
    libffi
    libxml2
    zlib
    openssl
  ];

  env = {
    LLVM_SYS_221_PREFIX = "${lib.getDev llvmPackages_22.llvm}";
    # Perry pins a nightly toolchain (-Z use-sync-unwind, float_algebraic)
    RUSTC_BOOTSTRAP = 1;
    OPENSSL_NO_VENDOR = 1;
  };

  postBuild = ''
    patchShebangs scripts/gc_call_effects/sidecars.sh

    scripts/gc_call_effects/sidecars.sh \
      target/${stdenv.hostPlatform.rust.rustcTargetSpec}/release
  '';

  # perry links user programs against these archives at compile time, and
  # shells out to clang (assembler for the statepoint rewrite) and cc (linker)
  postInstall = ''
    install -Dm644 target/${stdenv.hostPlatform.rust.rustcTargetSpec}/release/libperry_*.a* \
      -t $out/lib

    wrapProgram $out/bin/perry \
      --prefix PATH : ${
        lib.makeBinPath [
          stdenv.cc
          llvmPackages_22.clang
        ]
      } \
      --suffix LIBRARY_PATH : ${lib.makeLibraryPath [ openssl ]} \
      --set-default PERRY_LLVM_CLANG ${lib.getExe llvmPackages_22.clang} \
      --set-default PERRY_RUNTIME_DIR $out/lib \
      --set-default PERRY_NO_TELEMETRY 1
  '';

  # strip would rewrite the archives and invalidate their .gc-effects sidecars
  stripExclude = [ "*.a" ];

  # upstream runtime tests must run single-threaded and the gap suite needs
  # node 26.12.1 as an oracle, so the test suite is not run here.
  doCheck = false;

  __structuredAttrs = true;

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Native TypeScript compiler written in Rust";
    homepage = "https://www.perryts.com";
    downloadPage = "https://github.com/PerryTS/perry/releases";
    changelog = "https://github.com/PerryTS/perry/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirdukkkkk ];
    mainProgram = "perry";
    platforms = lib.platforms.linux;
  };
})
