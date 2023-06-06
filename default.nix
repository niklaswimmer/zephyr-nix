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
    outputHash = "sha256-+x5LVvvBjc8h74Zp4E6gCCTFDunNVI+eC999xU13g7U=";

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
      echo "OUTT: $out"
      mkdir "$out"
      cp -r * "$out"
    '';

    dontFixup = true;
  };
  shell = pkgs.mkShell {
    name = "syncubus-dev-shell";

    packages = [
      zephyr-toolchain
      zephyr-src

      pkgs.python310Packages.west

      # python packages defined in zephyr/scripts/requirements-base.txt
      pkgs.python310Packages.pyelftools
      pkgs.python310Packages.pyyaml
      pkgs.python310Packages.pykwalify
      pkgs.python310Packages.canopen
      pkgs.python310Packages.packaging
      pkgs.python310Packages.progress
      pkgs.python310Packages.psutil
      pkgs.python310Packages.pylink-square
      pkgs.python310Packages.anytree
      pkgs.python310Packages.intelhex
    ];

    ZEPHYR_BASE = "${zephyr-src}";

    shellHook = ''
      echo "Welcome to the SynCubus Firmware development environment. Happy coding!"
    '';
  };
}
