# Maintainer: françois <firmicus ατ gmx δοτ net> 

pkgname=texlive-localmanager
pkgver=0.3.0
pkgrel=1
pkgdesc="A shell and command-line utility to manage TeXLive on Arch Linux"
arch=('any')
url="http://wiki.archlinux.org/index.php?title=TeXLive#TeXLive_Local_Manager"
license=('GPL')
depends=('texlive-core>=2009' 'perl-libwww' 'perl-term-shellui' 'xz-utils')
source=("http://dev.archlinux.org/~francois/$pkgname-$pkgver.tar.gz")
md5sums=('50c59baca612d579ca5faa39749bb248')

build() {
  cd $srcdir/$pkgname
  install -d $pkgdir/usr/bin || return 1
  install -d $pkgdir/usr/share/texmf-var/arch/tlpkg/TeXLive || return 1
  install -m755 tllocalmgr $pkgdir/usr/bin/ || return 1
  cd tlpkg/TeXLive || return 1
  for f in *; do
    install -m644 $f $pkgdir/usr/share/texmf-var/arch/tlpkg/TeXLive/ || return 1
  done
}

# vim:set ts=2 sw=2 et:
