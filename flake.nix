{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [
            (import rust-overlay)
            (import ./rocksdb-overlay.nix)
          ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };
          inherit (pkgs) lib;
          rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

          src = craneLib.cleanCargoSource ./.;

          nativeBuildInputs = with pkgs; [ rustToolchain pkg-config clang ];
          buildInputs = with pkgs; [ openssl ];
          commonArgs = {
            inherit src buildInputs nativeBuildInputs;

            LIBCLANG_PATH = "${pkgs.libclang.lib}/lib"; # for rocksdb

            # link rocksdb dynamically
            ROCKSDB_INCLUDE_DIR = "${pkgs.rocksdb}/include";
            ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib";

          };
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;
          bin = craneLib.buildPackage (commonArgs // {
            inherit cargoArtifacts;
          });
        in
        with pkgs;
        {
          packages =
            {
              inherit bin;
              default = bin;
            };
          devShells.default = mkShell {
            inputsFrom = [ bin ];

            LIBCLANG_PATH = "${pkgs.libclang.lib}/lib"; # for building rocksdb

            # to link rocksdb dynamically
            ROCKSDB_INCLUDE_DIR = "${pkgs.rocksdb}/include";
            ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib";

            buildInputs = with pkgs; [ ];
          };
        }
      );
}
