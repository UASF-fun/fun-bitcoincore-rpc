{
  description = "Dev Environment Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.11";
  };

  outputs = { self, nixpkgs }: 
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };

  in
  {
    devShells.${system}.default =
    let
      overrides = (builtins.fromTOML (builtins.readFile ./rust-toolchain.toml));
      libPath = with pkgs; lib.makeLibraryPath [ ];

    in 
    pkgs.mkShell
    {
      packages = with pkgs; [
        just
        rustup
        clang
        llvmPackages.bintools
        cargo-watch
      ];

      RUSTC_VERSION = overrides.toolchain.channel;
      LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];
      # Add precompiled library to rustc search path
      RUSTFLAGS = (builtins.map (a: ''-L ${a}/lib'') [
        # add libraries here (e.g. pkgs.libvmi)
      ]);
      LD_LIBRARY_PATH = libPath;

      # Add glibc, clang, glib, and other headers to bindgen search path
      BINDGEN_EXTRA_CLANG_ARGS =
      # Includes normal include path
      (builtins.map (a: ''-I"${a}/include"'') [
        # add dev libraries here (e.g. pkgs.libvmi.dev)
        pkgs.glibc.dev
      ])
      # Includes with special directory paths
      ++ [
        ''-I"${pkgs.llvmPackages_latest.libclang.lib}/lib/clang/${pkgs.llvmPackages_latest.libclang.version}/include"''
        ''-I"${pkgs.glib.dev}/include/glib-2.0"''
        ''-I${pkgs.glib.out}/lib/glib-2.0/include/''
      ];

      shellHook = ''
        export PATH=$PATH:''${CARGO_HOME:-~/.cargo}/bin
        export PATH=$PATH:''${RUSTUP_HOME:-~/.rustup}/toolchains/$RUSTC_VERSION-x86_64-unknown-linux-gnu/bin/

        if ! command -v rust-analyzer >/dev/null 2>&1; then
          rustup component add rust-analyzer
        fi
      '';
    };
  };
}
