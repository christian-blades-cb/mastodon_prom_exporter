{ pkgs, toolchain, rust-analyzer, ... }:
pkgs.mkShell {
  nativeBuildInputs = [ pkgs.pkg-config pkgs.stdenv pkgs.openssl toolchain rust-analyzer ];
  RUST_SRC_PATH = "${toolchain}/lib/rustlib/src/rust/library";
}
