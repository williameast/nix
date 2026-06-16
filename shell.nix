{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Build tools
    gcc
    gnumake
    autoconf
    automake
    libtool
    pkg-config

    # Runtime dependencies for pdf-tools
    zlib
    zlib.dev
    poppler
    poppler.dev
    libpng
    libpng.dev
    libjpeg
    libjpeg.dev
    freetype
    freetype.dev

    # Other Emacs-related tools
    gnutls
    imagemagick
    sqlite
  ];

  shellHook = ''
    export PKG_CONFIG_PATH="${pkgs.zlib.dev}/lib/pkgconfig:${pkgs.poppler.dev}/lib/pkgconfig:${pkgs.libpng.dev}/lib/pkgconfig:${pkgs.libjpeg.dev}/lib/pkgconfig:${pkgs.freetype.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
    export LD_LIBRARY_PATH="${pkgs.zlib}/lib:${pkgs.poppler}/lib:${pkgs.libpng}/lib:${pkgs.libjpeg}/lib:${pkgs.freetype}/lib:$LD_LIBRARY_PATH"
  '';
}
