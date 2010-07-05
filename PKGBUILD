# Maintainer: Firmicus <francois . archlinux . org>

pkgname=texlive-localmanager
pkgver=0.4.0
pkgrel=1
pkgdesc="A shell and command-line utility to manage TeXLive on Arch Linux"
arch=('any')
url="http://wiki.archlinux.org/index.php?title=TeXLive#TeXLive_Local_Manager"
license=('GPL')
depends=('texlive-core>=2010' 'perl-libwww' 'perl-term-shellui' 'perl-term-readline-gnu' 'perl-list-moreutils')
source=("http://dev.archlinux.org/~francois/$pkgname-$pkgver.tar.xz")
md5sums=('af3d517932719f5912ded29084da6f95')

package() {
  cd $srcdir/$pkgname
  install -d $pkgdir/usr/bin || return 1
  install -d $pkgdir/var/lib/texmf/arch/tlpkg/TeXLive || return 1
  install -m755 tllocalmgr $pkgdir/usr/bin/ || return 1
  cd tlpkg/TeXLive || return 1
  for f in *; do
    install -m644 $f $pkgdir/var/lib/texmf/arch/tlpkg/TeXLive/ || return 1
  done
}

# vim:set ts=2 sw=2 et:
