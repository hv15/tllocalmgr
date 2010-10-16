# Maintainer: Rémy Oudompheng <remy@archlinux.org>
# Contributor: Firmicus <francois . archlinux . org>

pkgname=texlive-localmanager
pkgver=0.4.1
pkgrel=1
pkgdesc="A shell and command-line utility to manage TeXLive on Arch Linux"
arch=('any')
url="http://wiki.archlinux.org/index.php?title=TeXLive#TeXLive_Local_Manager"
license=('GPL')
depends=('texlive-core>=2010' 'perl-libwww' 'perl-term-shellui' 'perl-term-readline-gnu' 'perl-list-moreutils')
source=("http://dev.archlinux.org/~remy/$pkgname-$pkgver.tar.xz")
md5sums=('9c3f9e639d1caa850406f25f5d6a38d83dfc7ee')

package() {
  cd $srcdir/$pkgname
  install -d $pkgdir/usr/bin
  install -d $pkgdir/var/lib/texmf/arch/tlpkg/TeXLive
  install -m755 tllocalmgr $pkgdir/usr/bin/
  cd tlpkg/TeXLive
  for f in *; do
    install -m644 $f $pkgdir/var/lib/texmf/arch/tlpkg/TeXLive/
  done
}

# vim:set ts=2 sw=2 et:
