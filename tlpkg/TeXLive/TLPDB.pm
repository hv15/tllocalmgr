# $Id: TLPDB.pm 14083 2009-07-03 15:27:37Z preining $
# TeXLive::TLPDB.pm - module for using tlpdb files
# Copyright 2007, 2008 Norbert Preining
#
# This file is licensed under the GNU General Public License version 2
# or any later version.

package TeXLive::TLPDB;

=pod

=head1 NAME

C<TeXLive::TLPDB> -- A database of TeX Live Packages

=head1 SYNOPSIS

  use TeXLive::TLPDB;

  TeXLive::TLPDB->new ();
  TeXLive::TLPDB->new (root => "/path/to/texlive/installation/root");

  $tlpdb->root("/path/to/root/of/texlive/installation");
  $tlpdb->copy;
  $tlpdb->from_file($filename);
  $tlpdb->writeout;
  $tlpdb->writeout(FILEHANDLE);
  $tlpdb->save;
  $tlpdb->available_architectures();
  $tlpdb->add_tlpcontainer($pkg, $ziploc [, $archrefs [, $dest ]] );
  $tlpdb->add_tlpobj($tlpobj);
  $tlpdb->needed_by($pkg);
  $tlpdb->remove_package($pkg);
  $tlpdb->get_package("packagename");
  $tlpdb->list_packages;
  $tlpdb->expand_dependencies(["-only-arch",] $totlpdb, @list);
  $tlpdb->expand_dependencies(["-no-collections",] $totlpdb, @list);
  $tlpdb->find_file("filename");
  $tlpdb->collections;
  $tlpdb->schemes;
  $tlpdb->updmap_cfg_lines;
  $tlpdb->fmtutil_cnf_lines;
  $tlpdb->language_dat_lines;
  $tlpdb->language_def_lines;
  $tlpdb->package_revision("packagename");
  $tlpdb->location;
  $tlpdb->config_src_container;
  $tlpdb->config_doc_container;
  $tlpdb->config_container_format;
  $tlpdb->config_release;
  $tlpdb->config_revision;
  $tlpdb->options;
  $tlpdb->option($key, [$value]);
  $tlpdb->settings;
  $tlpdb->setting($key, [$value]);
  $tlpdb->sizes_of_packages($opt_src, $opt_doc [, @packs ]);

  TeXLive::TLPDB->listdir([$dir]);
  $tlpdb->generate_listfiles([$destdir]);

=head1 DESCRIPTION

=cut

use TeXLive::TLConfig qw($CategoriesRegexp $DefaultCategory $InfraLocation
      $DatabaseName $MetaCategoriesRegexp $Archive
      %TLPDBOptionType %TLPDBSettingType);
use TeXLive::TLUtils qw(dirname mkdirhier member win32 info debug ddebug
                        tlwarn);
use TeXLive::TLPOBJ;

use Cwd 'abs_path';

my $_listdir;

=pod

=over 4

=item C<< TeXLive::TLPDB->new >>

=item C<< TeXLive::TLPDB->new( [root => "$path"] ) >>

C<< TeXLive::TLPDB->new >> creates a new C<TLPDB> object. If the
argument C<root> is given it will be initialized from the respective
location within $path. If
C<$path> begins with C<http://> or C<ftp://>, the program C<wget>
is used to download the file.
The C<$path> can start with C<file:/> in which case it is treated as
a file on the filesystem in the usual way.

Returns either an object of type C<TeXLive::TLPDB>, or undef if the root
was given but no package could be read from that location.

=cut

sub new { 
  my $class = shift;
  my %params = @_;
  my $self = {
    root => $params{'root'},
    tlps => $params{'tlps'}
  };
  $_listdir = $params{'listdir'} if defined($params{'listdir'});
  bless $self, $class;
  if (defined($self->{'root'})) {
    my $nr_packages_read = $self->from_file("$self->{'root'}/$InfraLocation/$DatabaseName");
    if ($nr_packages_read == 0) {
      # that is bad, we cannot read anything, so return undef
      return(undef);
    }
  }
  return $self;
}


sub copy {
  my $self = shift;
  my $bla = {};
  %$bla = %$self;
  bless $bla, "TeXLive::TLPDB";
  return $bla;
}

=pod

=item C<< $tlpdb->add_tlpobj($tlpobj) >>

The C<add_tlpobj> adds an object of the type TLPOBJ to the TLPDB.

=cut

sub add_tlpobj {
  my ($self,$tlp) = @_;
  $self->{'tlps'}{$tlp->name} = $tlp;
}

=pod

=item C<< $tlpdb->needed_by($pkg) >>

Returns an array of package names depending on $pkg.

=cut

sub needed_by {
  my ($self,$pkg) = @_;
  my @ret;
  for my $p ($self->list_packages) {
    my $tlp = $self->get_package($p);
    DEPENDS: for my $d ($tlp->depends) {
      # exact match
      if ($d eq $pkg) {
        push @ret, $p;
        last DEPENDS;  # of the for loop on all depends
      }
      # 
      if ($d =~ m/^(.*)\.ARCH$/) {
        my $parent = $1;
        for my $a ($self->available_architectures) {
          if ($pkg eq "$parent.$a") {
            push @ret, $p;
            last DEPENDS;
          }
        }
      }
    }
  }
  return @ret;
}

=pod

=item C<< $tlpdb->remove_package($pkg) >>

Remove the package named C<$pkg> from the tlpdb. Gives a warning if the
package is not present

=cut

sub remove_package {
  my ($self,$pkg) = @_;
  if (defined($self->{'tlps'}{$pkg})) {
    delete $self->{'tlps'}{$pkg};
  } else {
    tlwarn("TLPDB: package to be removed not found: $pkg\n");
  }
}

=pod

=item C<< $tlpdb->from_file($filename) >>

The C<from_file> function initializes the C<TLPDB> if the root was not
given at generation time.  See L<TLPDB::new> for more information.

It returns the actual number of packages (TLPOBJs) read from C<$filename>.

=cut

sub from_file {
  my ($self, $path) = @_;
  if (@_ != 2) {
    die "$0: from_file needs filename for initialization";
  }
  my $root_from_path = dirname(dirname($path));
  if (defined($self->{'root'})) {
    if ($self->{'root'} ne $root_from_path) {
      tlwarn("root=$self->{'root'}, root_from_path=$root_from_path\n");
      tlwarn("Initialisation from different location as originally given.\nHope you are sure!\n");
    }
  } else {
    $self->root($root_from_path);
  }
  my $retfh;
  my $tlpdbfile;
  if ($path =~ m;^((http|ftp)://|file:\/\/*);) {
    debug("TLPDB.pm: trying to initialize from $path\n");
    # if we have xzdec available we try the xz file
    if (defined($::progs{'xzdec'})) {
      # we first try the xz compressed file
      my $tmpdir = TeXLive::TLUtils::get_system_tmpdir();
      my $bn = TeXLive::TLUtils::basename("$path");
      my $xzfile = "$tmpdir/$bn.$$.xz";
      my $xzfile_quote = $xzfile;
      # this is a variable of the whole sub as we have to remove the file
      # before returning
      $tlpdbfile = "$tmpdir/$bn.$$";
      my $tlpdbfile_quote = $tlpdbfile;
      if (win32()) {
        $xzfile  =~ s!/!\\!g;
        $tlpdbfile =~ s!/!\\!g;
      }
      $xzfile_quote = "\"$xzfile\"";
      $tlpdbfile_quote = "\"$tlpdbfile\"";
      debug("trying to download $path.xz to $xzfile\n");
      my $ret = TeXLive::TLUtils::download_file("$path.xz", "$xzfile");
      # better to check both, the return value AND the existence of the file
      if ($ret && (-r "$xzfile")) {
        # ok, let the fun begin
        debug("un-xzing $xzfile to $tlpdbfile\n");
        # xzdec *hopefully* returns 0 on success and anything else on failure
        # we don't have to negate since not zero means error in the shell
        # and thus in perl true
        if (system("$::progs{'xzdec'} <$xzfile_quote >$tlpdbfile_quote")) {
          debug("un-xzing $xzfile failed, tryin gplain file\n");
          # to be sure we unlink the xz file and the tlpdbfile
          unlink($xzfile);
          unlink($tlpdbfile);
        } else {
          unlink($xzfile);
          open($retfh, "<$tlpdbfile") || die "$0: open($tlpdbfile) failed: $!";
          debug("found the uncompressed xz file\n");
        }
      } 
    } else {
      debug("no xzdec defined, not trying tlpdb.xz ...\n");
    }
    if (!defined($retfh)) {
      debug("TLPDB: downloading $path.xz didn't succeed, try $path\n");
      # xz did not succeed, so try the normal file
      $retfh = TeXLive::TLUtils::download_file($path, "|");
      if (!$retfh) {
        die "open tlpdb($path) failed: $!";
      }
    }
  } else {
    open(TMP, "<$path") || die "$0: open($path) failed: $!";
    $retfh = \*TMP;
  }
  my $found = 0;
  my $ret = 0;
  do {
    my $tlp = TeXLive::TLPOBJ->new;
    $ret = $tlp->from_fh($retfh,1);
    if ($ret) {
      $self->add_tlpobj($tlp);
      $found++;
    }
  } until (!$ret);
  tlwarn("unusable location $path, could not load any packages\n") if (!$found);
  # remove the un-xz-ed tlpdb file from temp dir
  # THAT IS RACY!!! we should fix that in some better way with tempfile
  unlink($tlpdbfile) if $tlpdbfile;
  return($found);
}

=pod

=item C<< $tlpdb->writeout >>

=item C<< $tlpdb->writeout(FILEHANDLE) >>

The C<writeout> function writes the database to C<STDOUT>, or 
the file handle given as argument.

=cut

sub writeout {
  my $self = shift;
  my $fd = (@_ ? $_[0] : STDOUT);
  foreach (sort keys %{$self->{'tlps'}}) {
    ddebug("writeout: tlpname=$_  ", $self->{'tlps'}{$_}->name, "\n");
    $self->{'tlps'}{$_}->writeout($fd);
    print $fd "\n";
  }
}

=pod

=item C<< $tlpdb->save >>

The C<save> functions saves the C<TLPDB> to the file which has been set
as location. If the location is undefined, die.

=cut

sub save {
  my $self = shift;
  my $path = $self->location;
  mkdirhier(dirname($path));
  open(FOO, ">$path") || die "$0: open(>$path) failed: $!";
  $self->writeout(\*FOO);
  close(FOO);
}

=pod

=item C<< $tlpdb->available_architectures >>

The C<available_architectures> functions returns the list of available 
architectures as set in the options section 
(i.e., using setting("available_architectures"))

=cut

sub available_architectures {
  my $self = shift;
  my @archs = $self->setting("available_architectures");
  if (! @archs) {
    # fall back to the old method checking tex\.*
    my @packs = $self->list_packages;
    map { s/^tex\.// ; push @archs, $_ ; } grep(/^tex\.(.*)$/, @packs);
  }
  return @archs;
}

=pod

=item C<< $tlpdb->add_tlpcontainer($pkg, $ziploc [, $archrefs [, $dest ]] ) >>

Installs the package C<$pkg> from the container files in C<$ziploc>. If
C<$archrefs> is given then it must be a reference to a list of 
architectures to be installed. If the normal (arch=all) package is
architecture dependent then all arch packages in this list are installed.
If C<$dest> is given then the files are
installed into it, otherwise into the location of the TLPDB.

Note that this procedure does NOT check for dependencies. So if your package
adds new dependencies they are not necessarily fulfilled.

=cut

sub add_tlpcontainer {
  my ($self, $package, $ziplocation, $archrefs, $dest) = @_;
  my @archs;
  if (defined($archrefs)) {
    @archs = @$archrefs;
  }
  my $cwd = getcwd();
  if ($ziplocation !~ m,^/,) {
    $ziplocation = "$cwd/$ziplocation";
  }
  my $tlpobj = $self->_add_tlpcontainer($package, $ziplocation, "all", $dest);
  if ($tlpobj->is_arch_dependent) {
    foreach (@$archrefs) {
      $self->_add_tlpcontainer($package, $ziplocation, $_, $dest);
    }
  }
}

sub _add_tlpcontainer {
  my ($self, $package, $ziplocation, $arch, $dest) = @_;
  my $unpackprog;
  my $args;
  # WARNING: If you change the location of the texlive.tlpdb this
  # has to be changed, too!!
  if (not(defined($dest))) { 
    $dest = $self->{'root'};
  }
  my $container = "$ziplocation/$package";
  if ($arch ne "all") {
    $container .= ".$arch";
  }
  if (-r "$container.zip") {
    $container .= ".zip";
    $unpackprog="unzip";
    $args="-o -qq $container -d $dest";
  } elsif (-r "$container.xz") {
    $container .= ".xz";
    $unpackprog="NO_IDEA_HOW_TO_UNPACK_LZMA";
    $args="NO IDEA WHAT ARGS IT NEEDS";
    die "$0: xz checked for but not implemented, maybe update TLPDB.pm";
  } else {
    die "$0: No package $container (.zip or .xz) in $ziplocation";
  }
  tlwarn("Huuu, this needs testing and error checking!\n");
  tlwarn("Should we use -a -- adapt line endings etc?\n");
  `$unpackprog $args`;
  # we only create/add tlpobj for arch eq "all"
  if ($arch eq "all") {
    my $tlpobj = new TeXLive::TLPOBJ;
    $tlpobj->from_file("$dest/$TeXLive::TLConfig::InfraLocation/tlpobj/$package.tlpobj");
    $self->add_tlpobj($tlpobj);
    return $tlpobj;
  }
}


=pod

=item C<< $tlpdb->get_package("packagename") >> 

The C<get_package> function returns a reference to a C<TLPOBJ> object
in case its name the the argument name coincide.

=cut

sub get_package {
  my ($self,$pkg) = @_;
  if (defined($self->{'tlps'}{$pkg})) {
    return($self->{'tlps'}{$pkg});
  } else {
    return(undef);
  }
}

=pod

=item C<< $tlpdb->list_packages >>

The C<list_packages> function returns the list of all included packages.

=cut

sub list_packages {
  my $self = shift;
  return (sort keys %{$self->{'tlps'}});
}

=pod

=item C<< $tlpdb->expand_dependencies >>

This function takes as first argument the target TLPDB and then a list of
packages and returns the closure of this
list with respect to the depends operator. (Sorry, that was for
mathematicians)

If the very first argument is "-only-arch" then it expands only dependencies
of the form .ARCH.

If the very first argument is "-no-collections" then dependencies of 
collections onto collections are ignored.

=cut

sub expand_dependencies {
  my $self = shift;
  my $only_arch = 0;
  my $no_collections = 0;
  my $first = shift;
  my $totlpdb;
  if ($first eq "-only-arch") {
    $only_arch = 1;
    $totlpdb = shift;
  } elsif ($first eq "-no-collections") {
    $no_collections = 1;
    $totlpdb = shift;
  } else {
    $totlpdb = $first;
  }
  my %install = ();
  my @archs = $totlpdb->available_architectures;
  for my $p (@_) {
    $install{$p} = 1;
  }
  my $changed = 1;
  while ($changed) {
    $changed = 0;
    my @pre_select = keys %install;
    ddebug("pre_select = @pre_select\n");
    for my $p (@pre_select) {
      next if ($p =~ m/^00texlive/);
      my $pkg = $self->get_package($p);
      if (!defined($pkg)) {
        debug("W: $p is mentioned somewhere but not available, disabling\n");
        $install{$p} = 0;
        next;
      }
      for my $p_dep ($pkg->depends) {
        ddebug("checking $p_dep in $p\n");
        my $tlpdd = $self->get_package($p_dep);
        if (defined($tlpdd)) {
          if ($tlpdd->category =~ m/$MetaCategoriesRegexp/) {
            # we are taking a look at a dependency which is a collection
            # or scheme, and if the option "-no-collections" is given
            # we skip that one
            ddebug("expand_deps: skipping $p_dep in $p due to -no-collections\n");
            next if $no_collections;
          }
        }
        if ($p_dep =~ m/^(.*)\.ARCH$/) {
          my $foo = "$1";
          foreach $a (@archs) {
            $install{"$foo.$a"} = 1 if defined($self->get_package("$foo.$a"));
          }
        } elsif ($p_dep =~ m/^(.*)\.win32$/) {
          # a win32 package should *only* be installed if we are installing
          # the win32 arch
          if (grep(/^win32$/,@archs)) {
            $install{$p_dep} = 1;
          }
        } else {
          $install{$p_dep} = 1 unless $only_arch;
        }
      }
    }

    # check for newly selected packages
    my @post_select = keys %install;
    ddebug("post_select = @post_select\n");
    if ($#pre_select != $#post_select) {
      $changed = 1;
    }
  }
  return(keys %install);
}

=pod

=item C<< $tlpdb->find_file("filename") >>

The C<find_file> returns a list of packages:filename
containing a file named C<filename>.

=cut

sub find_file {
  my ($self,$fn) = @_;
  my @ret;
  foreach my $pkg ($self->list_packages) {
    my @foo = $self->get_package($pkg)->contains_file($fn);
    foreach my $f ($self->get_package($pkg)->contains_file($fn)) {
      push @ret, "$pkg:$f";
    }
  }
  return(@ret);
}

=pod

=item C<< $tlpdb->collections >>

The C<collections> function returns the list of all collections.

=cut

sub collections {
  my $self = shift;
  my @ret;
  foreach my $p ($self->list_packages) {
    if ($self->get_package($p)->category eq "Collection") {
      push @ret, $p;
    }
  }
  return @ret;
}

=pod

=item C<< $tlpdb->schemes >>

The C<collections> function returns the list of all schemes.

=cut

sub schemes {
  my $self = shift;
  my @ret;
  foreach my $p ($self->list_packages) {
    if ($self->get_package($p)->category eq "Scheme") {
      push @ret, $p;
    }
  }
  return @ret;
}



=pod

=item C<< $tlpdb->package_revision("packagename") >>

The C<package_revision> function returns the revision number of the
package named in the first argument.

=cut

sub package_revision {
  my ($self,$pkg) = @_;
  if (defined($self->{'tlps'}{$pkg})) {
    return($self->{'tlps'}{$pkg}->revision);
  } else {
    return(undef);
  }
}

=pod

=item C<< $tlpdb->generate_packagelist >>

The C<generate_packagelist> prints TeX Live package names in the object
database, together with their revisions, to the file handle given in the
first (optional) argument, or C<STDOUT> by default.  It also outputs all
available architectures as packages with revision number -1.

=cut

sub generate_packagelist {
  my $self = shift;
  my $fd = (@_ ? $_[0] : STDOUT);
  foreach (sort keys %{$self->{'tlps'}}) {
    print $fd $self->{'tlps'}{$_}->name, " ",
              $self->{'tlps'}{$_}->revision, "\n";
  }
  foreach ($self->available_architectures) {
    print $fd "$_ -1\n";
  }
}

=pod

=item C<< $tlpdb->generate_listfiles >>

=item C<< $tlpdb->generate_listfiles($destdir) >>

The C<generate_listfiles> generates the list files for the old 
installers. This function will probably go away.

=cut

sub generate_listfiles {
  my ($self,$destdir) = @_;
  if (not(defined($destdir))) {
    $destdir = TeXLive::TLPDB->listdir;
  }
  foreach (sort keys %{$self->{'tlps'}}) {
    $tlp = $self->{'tlps'}{$_};
    $self->_generate_listfile($tlp, $destdir);
  }
}

sub _generate_listfile {
  my ($self,$tlp,$destdir) = @_;
  my $listname = $tlp->name;
  my @files = $tlp->all_files;
  @files = TeXLive::TLUtils::sort_uniq(@files);
  &mkpath("$destdir") if (! -d "$destdir");
  my (@lop, @lot);
  foreach my $d ($tlp->depends) {
    my $subtlp = $self->get_package($d);
    if (defined($subtlp)) {
      if ($subtlp->is_meta_package) {
        push @lot, $d;
      } else {
        push @lop, $d;
      }
    } else {
      # speudo dependencies on $Package.ARCH can be ignored
      if ($d !~ m/\.ARCH$/) {
        tlwarn("TLPDB: package $tlp->name depends on $d, but this does not exist\n");
      }
    }
  }
  open(TMP, ">$destdir/$listname")
  || die "$0: open(>$destdir/$listname) failed: $!";

  # title and size information for collections and schemes in the
  # first two lines, marked with *
	if ($tlp->category eq "Collection") {
    print TMP "*Title: ", $tlp->shortdesc, "\n";
    # collections references Packages, we have to collect the sizes of
    # all the Package-tlps included
    # What is unclear for me is HOW the size is computed for bin-*
    # packages. The collection-basic contains quite a lot of
    # bin-files, but the sizes for the different archs differ.
    # I guess we have to take the maximum?
    my $s = 0;
    foreach my $p (@lop) {
      my $subtlp = $self->get_package($p);
      if (!defined($subtlp)) {
        tlwarn("TLPDB: $listname references $p, but it is not in tlpdb\n");
      }
      $s += $subtlp->total_size;
    }
    # in case the collection itself ships files ...
    $s += $tlp->runsize + $tlp->srcsize + $tlp->docsize;
    print TMP "*Size: $s\n";
  } elsif ($tlp->category eq "Scheme") {
    print TMP "*Title: ", $tlp->shortdesc, "\n";
    my $s = 0;
    # schemes size includes ONLY those packages which are directly
    # included and direclty included files, not the size of the
    # included collections. But if a package is included in one of
    # the called for collections AND listed directly, we don't want
    # to count its size two times
    my (@inccol,@incpkg,@collpkg);
    # first we add all the packages tlps that are directly included
    @incpkg = @lop;
    # now we select all collections, and for all collections we
    # again select all packages of type Documentation and Package
    foreach my $c (@lot) {
      my $coll = $self->get_package($c);
      foreach my $d ($coll->depends) {
        my $subtlp = $self->get_package($d);
        if (defined($subtlp)) {
          if (!($subtlp->is_meta_package)) {
            TeXLive::TLUtils::push_uniq(\@collpkg,$d);
          }
        } else {
          tlwarn("TLPDB: collection $coll->name depends on $d, but this does not exist\n");
        }
      }
    }
    # finally go through all packages and add the ->total_size
    foreach my $p (@incpkg) {
      if (!TeXLive::TLUtils::member($p,@collpkg)) {
        $s += $self->get_package($p)->total_size;
      }
    } 
    $s += $tlp->runsize + $tlp->srcsize + $tlp->docsize;
    print TMP "*Size: $s\n";
  }
  # dependencies and inclusion of packages
  foreach my $t (@lot) {
    # strange, schemes mark included collections via -, while collections
    # themself mark deps on other collections with +. collection are
    # never referenced in Packages
    if ($listname =~ m/^scheme/) {
      print TMP "-";
    } else {
      print TMP "+";
    }
    print TMP "$t\n";
  }
  foreach my $t (@lop) { print TMP "+$t\n"; }
  # included files
  foreach my $f (@files) { print TMP "$f\n"; }
  # also print the listfile itself
  print TMP "$destdir/$listname\n";
  # execute statements
  foreach my $e ($tlp->executes) {
    print TMP "!$e\n";
  }
  # finish
  close(TMP);
}

=pod

=item C<< $tlpdb->root([ "/path/to/installation" ]) >>

The function C<root> allows to read and set the root of the
installation. 

=cut

sub root {
  my $self = shift;
  if (@_) { $self->{'root'} = shift }
  return $self->{'root'};
}

=pod

=item C<< $tlpdb->location >>

Return the location of the actual C<texlive.tlpdb> file used. This is a
read-only function; you cannot change the root of the TLPDB using this
function.

See C<00texlive.installation.tlpsrc> for a description of the
special value C<__MASTER>.

=cut

sub location {
  my $self = shift;
  return "$self->{'root'}/$InfraLocation/$DatabaseName";
}

=pod

=item C<< $tlpdb->listdir >>

The function C<listdir> allows to read and set the packages variable
specifiying where generated list files are created.

=cut

sub listdir {
  my $self = shift;
  if (@_) { $_listdir = $_[0] }
  return $_listdir;
}

=pod

=item C<< $tlpdb->config_src_container >>

Returns 1 if the the texlive config option for src files splitting on 
container level is set. See Options below.

=cut

sub config_src_container {
  my $self = shift;
  if (defined($self->{'tlps'}{'00texlive.config'})) {
    foreach my $d ($self->{'tlps'}{'00texlive.config'}->depends) {
      if ($d eq "container_split_src_files") {
        return 1;
      }
    }
  }
  return 0;
}

=pod

=item C<< $tlpdb->config_doc_container >>

Returns 1 if the the texlive config option for doc files splitting on 
container level is set. See Options below.

=cut

sub config_doc_container {
  my $self = shift;
  if (defined($self->{'tlps'}{'00texlive.config'})) {
    foreach my $d ($self->{'tlps'}{'00texlive.config'}->depends) {
      if ($d eq "container_split_doc_files") {
        return 1;
      }
    }
  }
  return 0;
}

=pod

=item C<< $tlpdb->config_doc_container >>

Returns the currently set default container format. See Options below.

=cut

sub config_container_format {
  my $self = shift;
  if (defined($self->{'tlps'}{'00texlive.config'})) {
    foreach my $d ($self->{'tlps'}{'00texlive.config'}->depends) {
      if ($d =~ m!^container_format/(.*)$!) {
        return "$1";
      }
    }
  }
  return "";
}

=pod

=item C<< $tlpdb->config_release >>

Returns the currently set release. See Options below.

=cut

sub config_release {
  my $self = shift;
  if (defined($self->{'tlps'}{'00texlive.config'})) {
    foreach my $d ($self->{'tlps'}{'00texlive.config'}->depends) {
      if ($d =~ m!^release/(.*)$!) {
        return "$1";
      }
    }
  }
  return "";
}

=pod

=item C<< $tlpdb->config_revision >>

Returns the currently set revision. See Options below.

=cut

sub config_revision {
  my $self = shift;
  if (defined($self->{'tlps'}{'00texlive.config'})) {
    foreach my $d ($self->{'tlps'}{'00texlive.config'}->depends) {
      if ($d =~ m!^revision/(.*)$!) {
        return "$1";
      }
    }
  }
  return "";
}


=pod

=item C<< $tlpdb->sizes_of_packages ( $opt_src, $opt_doc, [ @packs ] ) >>

This function returns a reference to a hash with package names as keys
and the sizes in bytes as values. The sizes are computed for the arguments,
or all packages if nothing was given.

In case something has been computed one addition key is added C<__TOTAL__>
which contains the total size of all packages under discussion.

=cut

sub sizes_of_packages {
  my ($self, $opt_src, $opt_doc, @packs) = @_;
  @packs || ( @packs = $self->list_packages() );
  my $root = $self->root;
  my $media;
  if ($root =~ m!^(ctan$|(http|ftp)://)!i) {
    $media = 'NET';
  } else {
    $root =~ s!file://*!/!i;
    $root = abs_path($root);
    if (-d "$root/$Archive") {
      $media = 'CD';
    } elsif (-d "$root/texmf/web2c") {
      $media = 'DVD';
    } else {
      die "$0: that should not happen, no proper location found!";
    }
  }
  my %tlpsizes;
  my %tlpobjs;
  my $totalsize;
  foreach my $p (@packs) {
    $tlpobjs{$p} = $self->get_package($p);
    if (!defined($tlpobjs{$p})) {
      warn "STRANGE: $p not to be found in ", $self->root;
      next;
    }
    if ($media ne 'DVD') {
      # we use the container size as the measuring unit since probably
      # downloading will be the limiting factor
      $tlpsizes{$p} = $tlpobjs{$p}->containersize;
      $tlpsizes{$p} += $tlpobjs{$p}->srccontainersize if $opt_src;
      $tlpsizes{$p} += $tlpobjs{$p}->doccontainersize if $opt_doc;
    } else {
      # we have to add the respective sizes, that is checking for 
      # installation of src and doc file
      $tlpsizes{$p} = $tlpobjs{$p}->runsize;
      $tlpsizes{$p} += $tlpobjs{$p}->srcsize if $opt_src;
      $tlpsizes{$p} += $tlpobjs{$p}->docsize if $opt_doc;
      my %foo = %{$tlpobjs{$p}->binsize};
      for my $k (keys %foo) { $tlpsizes{$p} += $foo{$k}; }
      # all the packages sizes are in blocks, so transfer that to bytes
      $tlpsizes{$p} *= $TeXLive::TLConfig::BlockSize;
    }
    $totalsize += $tlpsizes{$p};
  }
  if ($totalsize) {
    $tlpsizes{'__TOTAL__'} = $totalsize;
  }
  return \%tlpsizes;
}




=pod

=item C<< $tlpdb->option($key [, $val]) >>
=item C<< $tlpdb->setting($key [, $val]) >>

Need to be documented

=cut

sub _set_option_value {
  my $self = shift;
  $self->_set_value_pkg('00texlive.installation', 'opt_', @_);
}
sub _set_setting_value {
  my $self = shift;
  $self->_set_value_pkg('00texlive.installation', 'setting_', @_);
}
sub _set_value_pkg {
  my ($self,$pkgname,$pre,$key,$value) = @_;
  my $k = "$pre$key";
  my $pkg = $self->{'tlps'}{$pkgname};
  my @newdeps;
  if (!defined($pkg)) {
    $pkg = new TeXLive::TLPOBJ;
    $pkg->name($pkgname);
    $pkg->category("TLCore");
    push @newdeps, "$k:$value";
  } else {
    my $found = 0;
    foreach my $d ($pkg->depends) {
      if ($d =~ m!^$k:!) {
        $found = 1;
        push @newdeps, "$k:$value";
      } else {
        push @newdeps, $d;
      }
    }
    if (!$found) {
      push @newdeps, "$k:$value";
    }
  }
  $pkg->depends(@newdeps);
  $self->{'tlps'}{$pkgname} = $pkg;
}

sub _option_value {
  my $self = shift;
  $self->_value_pkg('00texlive.installation', 'opt_', @_);
}

sub _setting_value {
  my $self = shift;
  $self->_value_pkg('00texlive.installation', 'setting_', @_);
}

sub _value_pkg {
  my ($self,$pkg,$pre,$key) = @_;
  my $k = "$pre$key";
  if (defined($self->{'tlps'}{$pkg})) {
    foreach my $d ($self->{'tlps'}{$pkg}->depends) {
      if ($d =~ m!^$k:(.*)$!) {
        return "$1";
      }
    }
    return;
  }
  tlwarn("$pkg not found, cannot read option $key.\n");
  return;
}

sub option_pkg {
  my $self = shift;
  my $pkg = shift;
  my $key = shift;
  if (@_) { $self->_set_value_pkg($pkg, "opt_", $key, shift); }
  my $ret = $self->_value_pkg($pkg, "opt_", $key);
  # special case for location == __MASTER__
  if ($ret eq "__MASTER__" && $key eq "location") {
    return $self->root;
  }
  return $ret;
}
sub option {
  my $self = shift;
  my $key = shift;
  if (@_) { $self->_set_option_value($key, shift); }
  my $ret = $self->_option_value($key);
  # special case for location == __MASTER__
  if (defined($ret) && $ret eq "__MASTER__" && $key eq "location") {
    return $self->root;
  }
  return $ret;
}
sub setting_pkg {
  my $self = shift;
  my $pkg = shift;
  my $key = shift;
  if (@_) { 
    if ($TLPDBSettingType{$key} eq "l") {
      $self->_set_value_pkg($pkg, "setting_", $key, "@_"); 
    } else {
      $self->_set_value_pkg($pkg, "setting_", $key, shift); 
    }
  }
  my $ret = $self->_value_pkg($pkg, "setting_", $key);
  # check the types of the settings, and if it is a "l" return a list
  if ($TLPDBSettingType{$key} eq "l") {
    my @ret;
    if (defined $ret) {
      @ret = split(" ", $ret);
    } else {
      tlwarn "TLPDB::setting: no $key, returning empty list ...\n";
      @ret = ();
    }
    return @ret;
  }
  return $ret;
}
sub setting {
  my $self = shift;
  my $key = shift;
  if (@_) { 
    if ($TLPDBSettingType{$key} eq "l") {
      $self->_set_setting_value($key, "@_"); 
    } else {
      $self->_set_setting_value($key, shift); 
    }
  }
  my $ret = $self->_setting_value($key);
  # check the types of the settings, and if it is a "l" return a list
  if ($TLPDBSettingType{$key} eq "l") {
    my @ret;
    if (defined $ret) {
      @ret = split(" ", $ret);
    } else {
      tlwarn "TLPDB::setting: no $key, returning empty list ...\n";
      @ret = ();
    }
    return @ret;
  }
  return $ret;
}

=pod

=item C<< $tlpdb->options >>

Returns a reference to a hash with option names.

=cut

sub _keyshash {
  my ($self, $pre, $hr) = @_;
  my @allowed = keys %$hr;
  my %ret;
  my $pkg = $self->{'tlps'}{'00texlive.installation'};
  if (defined($pkg)) {
    foreach my $d ($pkg->depends) {
      if ($d =~ m!^$pre([^:]*):(.*)!) {
        if (member($1, @allowed)) {
          $ret{$1} = $2;
        } else {
          tlwarn("Unsupported option/setting $d\n");
        }
      }
    }
  }
  return \%ret;
}

sub options {
  my $self = shift;
  return ($self->_keyshash('opt_', \%TLPDBOptionType));
}
sub settings {
  my $self = shift;
  return ($self->_keyshash('setting_', \%TLPDBSettingType));
}

=pod

=item C<< $tlpdb->format_definitions >>

This function returns a list of references to hashes where each hash
represents a parsed AddFormat line.


=cut

sub format_definitions {
  my $self = shift;
  my @ret;
  foreach my $p ($self->list_packages) {
    my $obj = $self->get_package ($p);
    die "$0: No TeX Live package named $p, strange" if ! $obj;
    push @ret, $obj->format_definitions;
  }
  return(@ret);
}

=item C<< $tlpdb->fmtutil_cnf_lines >>

The function C<fmtutil_cnf_lines> returns the list of a fmtutil.cnf file
containing only those formats present in the installation.

=cut
sub fmtutil_cnf_lines {
  my $self = shift;
  my @lines;
  foreach my $p ($self->list_packages) {
    my $obj = $self->get_package ($p);
    die "$0: No TeX Live package named $p, strange" if ! $obj;
    push @lines, $obj->fmtutil_cnf_lines;
  }
  return(@lines);
}

=item C<< $tlpdb->updmap_cfg_lines >>

The function C<updmap_cfg_lines> returns the list of a updmap.cfg file
containing only those maps present in the installation.

=cut
sub updmap_cfg_lines {
  my $self = shift;
  my @lines;
  foreach my $p ($self->list_packages) {
    my $obj = $self->get_package ($p);
    die "$0: No TeX Live package named $p, strange" if ! $obj;
    push @lines, $obj->updmap_cfg_lines;
  }
  return(@lines);
}

=item C<< $tlpdb->language_dat_lines >>

The function C<language_dat_lines> returns the list of all
lines for language.dat that can be generated from the tlpdb.

=cut

sub language_dat_lines {
  my $self = shift;
  my @lines;
  foreach my $p ($self->list_packages) {
    my $obj = $self->get_package ($p);
    die "$0: No TeX Live package named $p, strange" if ! $obj;
    push @lines, $obj->language_dat_lines;
  }
  return(@lines);
}

=item C<< $tlpdb->language_def_lines >>

The function C<language_def_lines> returns the list of all
lines for language.def that can be generated from the tlpdb.

=cut

sub language_def_lines {
  my $self = shift;
  my @lines;
  foreach my $p ($self->list_packages) {
    my $obj = $self->get_package ($p);
    die "$0: No TeX Live package named $p, strange" if ! $obj;
    push @lines, $obj->language_def_lines;
  }
  return(@lines);
}
    
=back

=pod

=head1 OPTIONS

Options regarding the full TeX Live installation to be described are saved
in a package C<00texlive.config> as values of C<depend> lines. This special
package C<00texlive.config> does not contain any files, only depend lines
which set one or more of the following options:

=over 4

=item C<container_split_src_files>

=item C<container_split_doc_files>

These options specify that at container generation time the source and
documentation files for a package have been put into a separate container
named C<package.source.extension> and C<package.doc.extension>.

=item C<container_format/I<format>>

This option specifies a format for containers. The currently supported 
formats are C<xz> and C<zip>. But note that C<zip> is untested.

=back

To set these options the respective lines should be added to
C<00texlive.config.tlpsrc>.

=head1 SEE ALSO

The modules L<TeXLive::TLPSRC>, L<TeXLive::TLPOBJ>, 
L<TeXLive::TLTREE>, L<TeXLive::TLUtils> and the
document L<Perl-API.txt> and the specification in the TeX Live
repository trunk/Master/tlpkg/doc/.

=head1 AUTHORS AND COPYRIGHT

This script and its documentation were written for the TeX Live
distribution (L<http://tug.org/texlive>) and both are licensed under the
GNU General Public License Version 2 or later.

=cut

1;

### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #
