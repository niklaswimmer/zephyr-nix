{ localSystem ? builtins.currentSystem }:
let
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/nixos/nixpkgs/archive/4d2b37a84fad1091b9de401eb450aae66f1a741e.tar.gz"; # tag: 23.05
    sha256 = "11w3wn2yjhaa5pv20gbfbirvjq6i3m7pqrq2msf0g7cv44vijwgw";
  };
  pkgs = import nixpkgs {
    # overlays and config would be impure otherwise (referencing files in the user home)
    overlays = [ ];
    config = { };
    # use the current system by default but allow overriding from callside
    inherit localSystem;
  };
  # get access to mach-nix's mkPython function
  inherit (import
    (pkgs.fetchFromGitHub {
      owner = "davhau";
      repo = "mach-nix";
      rev = "7e14360bde07dcae32e5e24f366c83272f52923f"; # tag: 3.5.0
      hash = "sha256-j/XrVVistvM+Ua+0tNFvO5z83isL+LBgmBi9XppxuKA=";
    })
    { inherit pkgs; }) mkPython;
in
rec {
  zephyr-toolchain = pkgs.fetchzip {
    pname = "zephyr-toolchain";
    version = "0.16.1";
    url = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.1/toolchain_linux-x86_64_arm-zephyr-eabi.tar.xz";
    hash = "sha256-3nLJ5K99XP9FJ+KRodHhKhNRBCWqLxnjxg4CuMbXKAw=";
  };
  zephyr-src = pkgs.stdenv.mkDerivation {
    pname = "zephyr-src";
    version = "3.3.0";

    outputHashMode = "recursive";
    outputHash = "sha256-JFM7ef6aVH8JjBero+lNA+Jd8Zamum75fBE64GJq8uI=";

    nativeBuildInputs = [ pkgs.python310Packages.west pkgs.git pkgs.cacert ];

    src = pkgs.fetchFromGitHub {
      name = "zephyr";
      owner = "zephyrproject-rtos";
      repo = "zephyr";
      rev = "07c6af3b8c35c1e49186578ca61a25c76e2fb308"; # tag: 3.3.0
      hash = "sha256-aE2MxbUN7tpgewjkQTNFSP1WfwX236mSOww0ADyENzo=";
    };

    # The sourceRoot defines the working directory for all phases after unpack. Nix uses
    # the unpacked source as default, which breaks with West, because West needs the
    # manifest repository as subdirectory of the current working directory. This snippet
    # creates a new directory which can be used as sourceRoot and copies the manifest
    # repository below it.
    #
    # `$NIX_BUILD_TOP` - top-level build directory
    # `$src`           - location of the zephyr-manifest bundle in the Nix store
    # `stripHash`      - strips the hash part of a Nix store path, leaving only the package's name
    setSourceRoot = ''
      sourceRoot="$NIX_BUILD_TOP/source"
      mkdir "$sourceRoot"
      cp -r "$NIX_BUILD_TOP/$(stripHash "$src")" "$sourceRoot"
    '';

    configurePhase = ''
      west init -l "$(stripHash "$src")"
    '';

    buildPhase = ''
      west update
      find . -type d -name ".git" -exec rm -rf {} +
    '';

    installPhase = ''
      mkdir "$out"
      cp -r * "$out"
    '';

    dontFixup = true;
  };
  zephyr-py-venv = mkPython {
    requirements = builtins.readFile "${zephyr-src}/zephyr-manifest-repo/scripts/requirements.txt";
  };
  shell = pkgs.mkShell {
    name = "syncubus-dev-shell";

    packages = [
      zephyr-toolchain
      zephyr-src
      zephyr-py-venv
      pkgs.python310Packages.west
    ];

    ZEPHYR_BASE = "${zephyr-src}";

    shellHook = ''
      echo "Welcome to the SynCubus Firmware development environment. Happy coding!"
    '';
  };
}
