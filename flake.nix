{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = inputs@{ self, nixpkgs, fenix, crane, flake-utils, gitignore, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        toolchain = fenix.packages.${system}.fromToolchainFile {
          dir = ./.;
          sha256 = "sha256-S7epLlflwt0d1GZP44u5Xosgf6dRrmr8xxC+Ml2Pq7c=";
        };
        pkgs = nixpkgs.legacyPackages.${system};
        craneLib = crane.lib.${system}.overrideToolchain toolchain;
      in {      
        packages.default = craneLib.buildPackage {
          src = gitignore.lib.gitignoreSource ./.;
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = with pkgs; [ pkg-config openssl ];
        };

        devShells.default = import ./shell.nix {
          inherit pkgs toolchain;
          rust-analyzer = fenix.packages.${system}.rust-analyzer;
        };
      }) // {
        nixosModule = import ./module.nix { inherit self; };
        nixosConfigurations.container = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            self.nixosModule
            {
              boot.isContainer = true;
              networking.firewall.allowedTCPPorts = [ 9121 ];
              
              services.mastodon_prom_exporter = {
                enable = true;
                port = 9121;
                host = "https://mastodon.social";
              };

              users.users.admin = {
                isNormalUser = true;
                initialPassword = "admin";
                extraGroups = [ "wheel" ];
              };

              services.openssh.passwordAuthentication = true;
              services.openssh.enable = true;
            }
          ];
        };
      };

  
}
