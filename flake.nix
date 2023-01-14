{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, fenix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        toolchain = fenix.packages.${system}.fromToolchainFile {
          dir = ./.;
          sha256 = "sha256-S7epLlflwt0d1GZP44u5Xosgf6dRrmr8xxC+Ml2Pq7c=";
        };
        pkgs = nixpkgs.legacyPackages.${system};
        rustPlatform = pkgs.makeRustPlatform {
          cargo = toolchain;
          rustc = toolchain;
        };        
      in {      
      packages.default = rustPlatform.buildRustPackage {
          pname = "mastodon_prom_exporter";
          version = "0.1.0";

          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = with pkgs; [ pkg-config openssl ];
          src = ./.;
          
          cargoLock.lockFile = ./Cargo.lock;
        };

      devShells.default = import ./shell.nix {
        inherit pkgs toolchain;
        rust-analyzer = fenix.packages.${system}.rust-analyzer;
      };
    });

  
}
