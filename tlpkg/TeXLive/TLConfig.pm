# $Id: TLConfig.pm 14553 2009-08-06 13:20:26Z preining $
# TeXLive::TLConfig.pm - module exporting configuration stuff
# Copyright 2007, 2008, 2009 Norbert Preining
# This file is licensed under the GNU General Public License version 2
# or any later version.

package TeXLive::TLConfig;

my $svnrev = '$Revision: 14553 $';
my $_modulerevision;
if ($svnrev =~ m/: ([0-9]+) /) {
  $_modulerevision = $1;
} else {
  $_modulerevision = "unknown";
}
sub module_revision {
  return $_modulerevision;
}

BEGIN {
  use Exporter ();
  use vars qw( @ISA @EXPORT_OK @EXPORT );
  @ISA = qw(Exporter);
  @EXPORT_OK = qw(
    $ReleaseYear
    @MetaCategories
    @NormalCategories
    @Categories
    $MetaCategoriesRegexp
    $CategoriesRegexp
    $DefaultCategory
    $DefaultContainerFormat
    $DefaultContainerExtension
    $InfraLocation
    $DatabaseName
    $BlockSize
    $Archive
    $TeXLiveServerURL
    $TeXLiveServerPath
    $TeXLiveURL
    @CriticalPackagesList
    $CriticalPackagesRegexp
    $WindowsMainMenuName
    $RelocPrefix
    $RelocTree
    %TLPDBOptions
    %TLPDBSettings
    %TLPDBConfigs
  );
  @EXPORT = @EXPORT_OK;
}

# the year of our release, will be used in the location of the
# network packges, and in menu names, and probably many other places
$ReleaseYear = 2009;

# Meta Categories do not ship files, but call only for other packages
our @MetaCategories = qw/Collection Scheme/;
our $MetaCategoriesRegexp = '(Collection|Scheme)';
#
# Normal Categories contain actial files and do not depend on other things.
our @NormalCategories = qw/Package TLCore ConTeXt/;
#
# list of all Categories
our @Categories = (@MetaCategories, @NormalCategories);

# repeat, as a regexp.
our $CategoriesRegexp = '(Collection|Scheme|Package|TLCore|ConTeXt)';

our $DefaultCategory = "Package";

# location of various infra files (texlive.tlpdb, .tlpobj etc)
# relative to a root (e.g., the Master/, or the installation path)
our $InfraLocation = "tlpkg";
our $DatabaseName = "texlive.tlpdb";

our $BlockSize = 4096;

# the way we package things on the web
our $DefaultContainerFormat = "xz";
our $DefaultContainerExtension = "tar.$DefaultContainerFormat";

our $Archive = "archive";
our $TeXLiveServerURL = "http://mirror.ctan.org";
# from 2009 on we try to put them all into tlnet directly without any
# release year since we hope that we can switch over to 2010 on the fly
# our $TeXLiveServerPath = "systems/texlive/tlnet/$ReleaseYear";
our $TeXLiveServerPath = "systems/texlive/tlnet";
our $TeXLiveURL = "$TeXLiveServerURL/$TeXLiveServerPath";
our $RelocTree = "texmf-dist";
our $RelocPrefix = "RELOC";

our @CriticalPackagesList = qw/texlive.infra/;
our $CriticalPackagesRegexp = '^(texlive\.infra)';
if ($^O=~/^MSWin(32|64)$/i) {
  push(@CriticalPackagesList, "tlperl.win32");
  $CriticalPackagesRegexp = '^(texlive\.infra|tlperl\.win32$)';
}

#
# stuff formerly set in 00texlive.config
#
our %TLPDBConfigs = (
  "container_split_src_files" => 1,
  "container_split_doc_files" => 1,
  "container_format" => $DefaultContainerFormat,
  "release" => $ReleaseYear );

#
# definition of the option strings and their value types 
# possible types are:
# - u: url
# - b: boolean, saved as 0/1
# - p: path (local path)
# - n: naturnal number
#      it allows n:[a]..[b]
#         if a is empty start at -infty
#         if b is empty end at +infty
#      so "n:.." is equivalent to "n"

# WARNING: keep these in sync!
#
# $TLPDBOptions{"option"}->[0] --> type
#                        ->[1] --> default value
#                        ->[2] --> tlmgr name
#                        ->[3] --> tlmgr description

our %TLPDBOptions = (
  "location" =>
    [ "u", "__MASTER__",
      "location", 
      "Default installation location" ],
  "create_formats" =>
    [ "b", 1,
      "formats",  
      "Create formats on installation" ],
  "desktop_integration" =>
    [ "b", 1,
      "desktop_integration",
      "Create shortcuts (menu and desktop) in postinst" ],
  "file_assocs" =>
    [ "n:0..2", 1,
      "fileassocs",
      "Change file associations in postinst" ],
  "post_code" =>
    [ "b", 1,
      "postcode",
      "Run postinst code blobs" ],
  "sys_bin" =>
    [ "p", "/usr/local/bin",
      "sys_bin",
      "Destination for symlinks for binaries" ],
  "sys_man" =>
    [ "p", "/usr/local/man",
      "sys_man",
      "Destination for symlinks for man pages" ],
  "sys_info" =>
    [ "p", "/usr/local/info",
      "sys_info",
      "Destination for symlinks for info docs" ],
  "install_docfiles" =>
    [ "b", 1,
      "docfiles",
      "Install documentation files" ],
  "install_srcfiles" =>
    [ "b", 1,
      "srcfiles",
      "Install source files" ],
  "w32_multi_user" =>
    [ "b", 1,
      "multiuser",
      "Install for shortcuts/menu items for all users (w32)" ],
  "autobackup" =>
    [ "n:-1..", 0,
      "autobackup",
      "Number of backups to keep" ],
  "backupdir" =>
    [ "p", "",
      "backupdir",
      "Directory for backups" ],
  );


our %TLPDBSettings = (
  "platform" => [ "s", "Main platform for this computer" ],
  "available_architectures" => [ "l", "All available/installed architectures" ]
);

our $WindowsMainMenuName = "TeX Live $ReleaseYear";


1;


=head1 NAME

C<TeXLive::TLConfig> -- TeX Live Configurations

=head1 SYNOPSIS

  use TeXLive::TLConfig;

=head1 DESCRIPTION

The L<TeXLive::TLConfig> module contains definitions of variables 
configuring all of TeX Live.

=over 4

=head1 EXPORTED VARIABLES

All of the following variables are pulled into the callers namespace,
i.e., are declared with C<EXPORT> (and C<EXPORT_OK>).

=item C<@TeXLive::TLConfig::MetaCategories>

The list of meta categories, i.e., those categories whose packages only
depend on other packages, but don't ship any files. Currently 
C<Collection> and <Scheme>.

=item C<@TeXLive::TLConfig::NormalCategories>

The list of normal categories, i.e., those categories whose packages do
ship files. Currently C<TLCore>, C<Package>, C<ConTeXt>.

=item C<@TeXLive::TLConfig::Categories>

The list of all categories, i.e., the union of the above.

=item C<$TeXLive::TLConfig::CategoriesRegexp>

A regexp matching any category.

=item C<$TeXLive::TLConfig::DefaultCategory>

The default category used when creating new packages.

=item C<$TeXLive::TLConfig::InfraLocation>

The subdirectory with various infrastructure files (C<texlive.tlpdb>,
tlpobj files, ...) relative to the root of the installation; currently
C<tlpkg>.

=item C<$TeXLive::TLConfig::BlockSize>

The assumed block size, currently 4k.

=item C<$TeXLive::TLConfig::Archive>
=item C<$TeXLive::TLConfig::TeXLiveURL>

These values specify where to find packages.

=item C<$TeXLive::TLConfig::TeXLiveServerURL>
=item C<$TeXLive::TLConfig::TeXLiveServerPath>

C<TeXLiveURL> is concatencated from these values, with a string between.
The defaults are respectively, C<http://mirror.ctan.org> and
C<systems/texlive/tlnet/>I<rel>, where I<rel> specifies the TeX Live
release version, such as C<tldev> or C<2008>.

=item C<@TeXLive::TLConfig::CriticalPackagesList>
=item C<@TeXLive::TLConfig::CriticalPackagesRegexp>

A list of all those packages which we do not update regularly
since they are too central, currently only texlive.infra (and tlperl.win32
for Windows).

=item C<$TeXLive::TLConfig::RelocTree>

the texmf-tree name that can be relocated, defaults to "texmf-dist"

=item C<$TeXLive::TLConfig::RelocPrefix>

The string that replaces the RelocTree in the tlpdb if a package is
reloaced, defaults to "RELOC".

=back

=head1 SEE ALSO

The modules L<TeXLive::TLUtils>, L<TeXLive::TLPSRC>,
L<TeXLive::TLPDB>, L<TeXLive::TLTREE>, L<TeXLive::TeXCatalogue>.

=head1 AUTHORS AND COPYRIGHT

This script and its documentation were written for the TeX Live
distribution (L<http://tug.org/texlive>) and both are licensed under the
GNU General Public License Version 2 or later.

=cut

### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #
