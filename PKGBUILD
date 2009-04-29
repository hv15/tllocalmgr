# Maintainer: françois <firmicus ατ gmx δοτ net> 

pkgname=texlive-localmanager
pkgver=0.2.4
pkgrel=2
pkgdesc="A shell and command-line utility to manage TeXLive on Arch Linux"
arch=('i686' 'x86_64')
url="http://wiki.archlinux.org/index.php?title=TeXLive#TeXLive_Local_Manager"
license=('GPL')
depends=('texlive-core>=2008.11906-1' 'perl-libwww' 'perl-term-shellui' 'lzma-utils')
source=("http://dev.archlinux.org/~francois/$pkgname-$pkgver.gz"
        "http://dev.archlinux.org/~francois/docpkglists.tar.gz"
        "http://dev.archlinux.org/~francois/texlive.infra.tar.lzma")
md5sums=('c55f6c72eb66327622b6d5736cce2861'
         '590cf23c2779d1d3aaae77943013b3f3'
         'aafc24c81e8c3af112bb732095b462cb')

build() {
  cd $srcdir
  install -d $pkgdir/usr/bin || return 1
  install -d $pkgdir/usr/share/texmf-var/arch/tlpkg/TeXLive || return 1
  install -d $pkgdir/usr/share/texmf-var/arch/installedpkgs/ || return 1
  install -m755 $pkgname-$pkgver $pkgdir/usr/bin/tllocalmgr || return 1
  install -m644 pkglist/*.pkgs $pkgdir/usr/share/texmf-var/arch/installedpkgs/ || return 1
  lzma --force -dc texlive.infra.tar.lzma | tar xf - || return 1
  cd tlpkg/TeXLive || return 1
  for f in TLConfig TLPDB TLPOBJ TLTREE TLUtils; do
    install -m644 $f.pm $pkgdir/usr/share/texmf-var/arch/tlpkg/TeXLive/ || return 1
  done
}

# vim:set ts=2 sw=2 et:
