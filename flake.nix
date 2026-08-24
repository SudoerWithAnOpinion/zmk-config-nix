{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # This pins requirements.txt provided by zephyr-nix.pythonEnv.
    zephyr.url = "github:zmkfirmware/zephyr/v4.1.0+zmk-fixes";
    zephyr.flake = false;

    # Zephyr sdk and toolchain.
    zephyr-nix.url = "github:nix-community/zephyr-nix";
    zephyr-nix.inputs.zephyr.follows = "zephyr";
    zephyr-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Devicetree linter; use my fork for nix-package and ZMK-specific tweaks.
    dts-linter.url = "github:urob/dts-linter/zmk";
    dts-linter.inputs.nixpkgs.follows = "nixpkgs";

    # West manifest locking; skipping the flake to build its package.nix with
    # our own nixpkgs and python package set.
    pin-west.url = "github:urob/pin-west";
    pin-west.flake = false;

    # OpenSCAD keycap generator.
    keyv2.url = "github:rsheldiii/KeyV2";
    keyv2.flake = false;
  };

  outputs = inputs @ { nixpkgs, zephyr-nix, dts-linter, ... }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    devShells = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        zephyr = inputs.zephyr-nix.packages.${system};
        keymap-drawer = pkgs.python3Packages.callPackage ./nix/keymap-drawer.nix {};
        pin-west = pkgs.python3Packages.callPackage "${inputs."pin-west"}/package.nix" {};
        dts-format = pkgs.callPackage ./nix/dts-format.nix {
          dts-linter = pkgs.callPackage ./nix/dts-linter.nix {
            # Uncomment to build against the pinned dts-lsp instead of the
            # server bundled with dts-linter.
            # dts-lsp-server = pkgs.callPackage ./nix/dts-lsp-server.nix {};
          };
        };
      in {
        default = pkgs.mkShellNoCC {
          packages =
            [
              zephyr.pythonEnv
              (zephyr.sdk-0_16.override {targets = ["arm-zephyr-eabi"];})

              pkgs.cmake
              pkgs.dtc
              pkgs.gcc
              pkgs.ninja
              pkgs.protobuf

              pkgs.just
              pkgs.yq # Make sure yq resolves to python-yq.
              pkgs.python3Packages.protobuf

              keymap-drawer
              dts-format
              pin-west
              pkgs.librsvg
              pkgs.inkscape
              pkgs.fontconfig

              # -- Used by just_recipes and west_commands. Most systems already have them. --
              pkgs.gawk
              pkgs.unixtools.column
              pkgs.coreutils # cp, cut, echo, mkdir, sort, tail, tee, uniq, wc
              pkgs.diffutils
              pkgs.findutils # find, xargs
              pkgs.gnugrep
              pkgs.gnused
            ];

          env = {
            PYTHONPATH = "${zephyr.pythonEnv}/${zephyr.pythonEnv.sitePackages}";
          };

          shellHook = ''
            export ZMK_BUILD_DIR=$(pwd)/.build;
            export ZMK_SRC_DIR=$(pwd)/zmk/app;
            export KEYV2_DIR="${inputs.keyv2}";
            export OPENSCADPATH="${inputs.keyv2}";

            export ZMK_FONTS_DIR=$(pwd)/assets/fonts
            export FONTCONFIG_FILE=$(pwd)/.fontconfig-zmk.xml
            cat > "$FONTCONFIG_FILE" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>$ZMK_FONTS_DIR</dir>
</fontconfig>
EOF
          ''
          + (if pkgs.stdenv.isLinux then
            let libatomic = pkgs.runCommand "libatomic" {} ''
              mkdir -p $out/lib
              cp -d ${pkgs.stdenv.cc.cc.lib}/lib/libatomic.so* $out/lib/
            ''; in ''
            export LD_LIBRARY_PATH="${libatomic}/lib";
          '' else "");
        };
      }
    );
  };
}
