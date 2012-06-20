# $Id: TLTREE.pm 26615 2012-05-24 00:39:35Z karl $
# TeXLive::TLTREE.pm - work with the tree of all files
# Copyright 2007-2012 Norbert Preining
# This file is licensed under the GNU General Public License version 2
# or any later version.

package TeXLive::TLTREE;

my $svnrev = '$Revision: 26615 $';
my $_modulerevision;
if ($svnrev =~ m/: ([0-9]+) /) {
  $_modulerevision = $1;
} else {
  $_modulerevision = "unknown";
}
sub module_revision {
  return $_modulerevision;
}

use TeXLive::TLUtils;

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    svnroot   => $params{'svnroot'},
    archs     => $params{'archs'},
    revision  => $params{'revision'},
    # private stuff
    _allfiles   => {},
    _dirtree    => {},
    _dirnames   => {},
    _filesofdir => {},
    _subdirsofdir => {},
  };
  bless $self, $class;
  return $self;
}

sub init_from_svn {
  my $self = shift;
  die "undefined svn root" if !defined($self->{'svnroot'});
  my @lines = `cd $self->{'svnroot'} && svn status -v`;
  my $retval = $?;
  if ($retval != 0) {
    $retval /= 256 if $retval > 0;
    tldie("TLTree: svn status -v returned $retval, stopping.\n");
  }
  $self->_initialize_lines(@lines);
}

sub init_from_statusfile {
  my $self = shift;
  die "need filename of svn status file" if (@_ != 1);
  open(TMP,"<$_[0]") || die "open of svn status file($_[0]) failed: $!";
  my @lines = <TMP>;
  close(TMP);
  $self->_initialize_lines(@lines);
}
sub init_from_files {
  my $self = shift;
  my $svnroot = $self->{'svnroot'};
  my @lines = `find $svnroot`;
  my $retval = $?;
  if ($retval != 0) {
    $retval /= 256 if $retval > 0;
    tldie("TLTree: find $svnroot returned $retval, stopping.\n");
  }
  @lines = grep(!/\/\.svn/ , @lines);
  @lines = map { s@^$svnroot@@; s@^/@@; "             1 1 dummy $_" } @lines;
  $self->{'revision'} = 1;
  $self->_initialize_lines(@lines);
}

sub _initialize_lines {
  my $self = shift;
  my @lines = @_;
  my %archs;
  # we first chdir to the svn root, we need it for file tests
  chomp (my $oldpwd = `pwd`);
  chdir($self->svnroot) || die "chdir($self->{svnroot}) failed: $!";
  foreach my $l (@lines) {
    chomp($l);
    next if $l =~ /^\?/;    # ignore files not under version control
    if ($l =~ /^(.)(.)(.)(.)(.)(.)..\s*(\d+)\s+([\d\?]+)\s+([\w\?]+)\s+(.+)$/){
      $self->{'revision'} = $7 unless defined($self->{'revision'});
      my $lastchanged = ($8 eq "?" ? 1 : $8);
      my $entry = "$10";
      next if ($1 eq "D"); # ignore files which are removed
      next if -d $entry && ! -l $entry; # keep symlinks to dirs (bin/*/man),
                                        # ignore normal dirs.
      # collect architectures, assuming nothing is in bin/ but arch subdirs.
      if ($entry =~ m,^bin/([^/]*)/,) {
        $archs{$1} = 1;
      }
      $self->{'_allfiles'}{$entry}{'lastchangedrev'} = $lastchanged;
      $self->{'_allfiles'}{$entry}{'size'} = (lstat $entry)[7];
      my $fn = TeXLive::TLUtils::basename($entry);
      my $dn = TeXLive::TLUtils::dirname($entry);
      add_path_to_tree($self->{'_dirtree'}, split("[/\\\\]", $dn));
      push @{$self->{'_filesofdir'}{$dn}}, $fn;
    } elsif ($l ne '             1 1 dummy ') {
      tlwarn("Ignoring svn status output line:\n    $l\n");
    }
  }
  # save list of architectures
  $self->architectures(keys(%archs));
  # now do some magic
  # - create list of top level dirs with a list of full path names of
  #   the respective dir attached
  $self->walk_tree(\&find_alldirs);
  
  chdir($oldpwd) || die "chdir($oldpwd) failed: $!";
}

sub print {
  my $self = shift;
  $self->walk_tree(\&print_node);
}

sub find_alldirs {
  my ($self,$node, @stackdir) = @_;
  my $tl = $stackdir[-1];
  push @{$self->{'_dirnames'}{$tl}}, join("/", @stackdir);
  if (keys(%{$node})) {
    my $pa = join("/", @stackdir);
    push @{$self->{'_subdirsofdir'}{$pa}}, keys(%{$node});
  }
}

sub print_node {
  my ($self,$node, @stackdir) = @_;
  my $dp = join("/", @stackdir);
  if ($self->{'_filesofdir'}{$dp}) {
    foreach my $f (@{$self->{'_filesofdir'}{$dp}}) {
      print "dp=$dp file=$f\n";
    }
  }
  if (! keys(%{$node})) {
    print join("/", @stackdir) . "\n";
  }
}

sub walk_tree {
  my $self = shift;
  my (@stack_dir);
  $self->_walk_tree1($self->{'_dirtree'},@_, @stack_dir);
}

sub _walk_tree1 {
  my $self = shift;
  my ($node,$pre_proc, $post_proc, @stack_dir) = @_;
  my $v;
  for my $k (keys(%{$node})) {
    push @stack_dir, $k;
    $v = $node->{$k};
    if ($pre_proc) { &{$pre_proc}($self, $v, @stack_dir) }
    $self->_walk_tree1 (\%{$v}, $pre_proc, $post_proc, @stack_dir);
    $v = $node->{$k};
    if ($post_proc) { &{$post_proc}($self, $v, @stack_dir) }
    pop @stack_dir;
  }
}

sub add_path_to_tree {
  my ($node, @path) = @_;
  my ($current);

  while (@path) {
    $current = shift @path;
    if ($$node{$current}) {
      $node = $$node{$current};
    } else {
      $$node{$current} = { };
      $node = $$node{$current};
    }
  }
  return $node;
}

sub file_svn_lastrevision {
  my $self = shift;
  my $fn = shift;
  if (defined($self->{'_allfiles'}{$fn})) {
    return($self->{'_allfiles'}{$fn}{'lastchangedrev'});
  } else {
    return(undef);
  }
}

sub size_of {
  my ($self,$f) = @_;
  if (defined($self->{'_allfiles'}{$f})) {
    return($self->{'_allfiles'}{$f}{'size'});
  } else {
    return(undef);
  }
}

# return a per-architecture hash ref for TYPE eq "bin",
# list ref for all others.
# 
=pod

The function B<get_matching_files> takes as arguments the type of the pattern
(bin, src, doc, run), the pattern itself, the package name (without
.ARCH specifications), and an optional architecture.
It returns a list of files matching that pattern (in the case
of bin patterns for that arch).

=cut

sub get_matching_files {
  my ($self, $type, $p, $pkg, $arch) = @_;
  my $ARCH = $arch;
  my $PKGNAME = $pkg;
  my $newp;
  eval "\$newp = \"$p\"";
  if (!defined($newp)) {
    print "Huuu: cannot generate newp from p: p=$p, pkg=$pkg, arch=$arch, type=$type\n";
  }
  return($self->_get_matching_files($type,$newp));
}

  
sub _get_matching_files {
  my ($self, $type, $p) = @_;
  my ($pattype,$patdata,@rest) = split ' ',$p;
  my @matchfiles;
  if ($pattype eq "t") {
    @matchfiles = $self->_get_files_matching_dir_pattern($type,$patdata,@rest);
  } elsif ($pattype eq "f") {
    @matchfiles = $self->_get_files_matching_glob_pattern($type,$patdata);
  } elsif ($pattype eq "r") {
    @matchfiles = $self->_get_files_matching_regexp_pattern($type,$patdata);
  } elsif ($pattype eq "d") {
    @matchfiles = $self->files_under_path($patdata);
  } else {
    die "Unknown pattern pattern type `$pattype' in $p";
  }
  ddebug("p=$p; matchfiles=@matchfiles\n");
  return @matchfiles;
}

#
# we transform a glob pattern to a regexp pattern:
# currently supported globs: ? *
#
# sequences of subsitutions:
#   . -> \.
#   * -> .*
#   ? -> .
#   + -> \+
sub _get_files_matching_glob_pattern
{
  my $self = shift;
  my ($type,$globline) = @_;
  my @returnfiles;

  my $dirpart = TeXLive::TLUtils::dirname($globline);
  my $basepart = TeXLive::TLUtils::basename($globline);
  $basepart =~ s/\./\\./g;
  $basepart =~ s/\*/.*/g;
  $basepart =~ s/\?/./g;
  $basepart =~ s/\+/\\+/g;
  return unless (defined($self->{'_filesofdir'}{$dirpart}));

  my @candfiles = @{$self->{'_filesofdir'}{$dirpart}};
  for my $f (@candfiles) {
    ddebug("matching $f in $dirpart via glob $globline\n");
    if ($f =~ /^$basepart$/) {
      ddebug("hit: globline=$globline, $dirpart/$f\n");
      if ("$dirpart" eq ".") {
        push @returnfiles, "$f";
      } else {
        push @returnfiles, "$dirpart/$f";
      }
    }
  }

  if ($dirpart =~ m,^bin/(win32|i386-cygwin),
      || $dirpart =~ m,tlpkg/installer,) {
    # for windows-iwsh we want to automatch more extensions.
    foreach my $f (@candfiles) {
      my $w32_binext;
      if ($dirpart =~ m,^bin/i386-cygwin,) {
        $w32_binext = "exe";  # cygwin has .exe but nothing else
      } else {
        $w32_binext = "(exe|dll)(.manifest)?|texlua|bat|cmd";
      }
      ddebug("matching $f in $dirpart via glob $globline.($w32_binext)\n");
      if ($f =~ /^$basepart\.($w32_binext)$/) {
        ddebug("hit: globline=$globline, $dirpart/$f\n");
        if ("$dirpart" eq ".") {
          push @returnfiles, "$f";
        } else {
          push @returnfiles, "$dirpart/$f";
        }
      }
    }
  }
  return @returnfiles;
}

sub _get_files_matching_regexp_pattern {
  my $self = shift;
  my ($type,$regexp) = @_;
  my @returnfiles;
  FILELABEL: foreach my $f (keys(%{$self->{'_allfiles'}})) {
    if ($f =~ /^$regexp$/) {
      TeXLive::TLUtils::push_uniq(\@returnfiles,$f);
      next FILELABEL;
    }
  }
  return(@returnfiles);
}

sub _get_files_matching_dir_pattern {
  my ($self,$type,@patwords) = @_;
  my $tl = pop @patwords;
  my @returnfiles;
  if (defined($self->{'_dirnames'}{$tl})) {
    foreach my $tld (@{$self->{'_dirnames'}{$tl}}) {
      if (index($tld,join("/",@patwords)."/") == 0) {
        my @files = $self->files_under_path($tld);
        TeXLive::TLUtils::push_uniq(\@returnfiles, @files);
      }
    }
  }
  return(@returnfiles);
}

sub files_under_path {
  my $self = shift;
  my $p = shift;
  my @files = ();
  foreach my $aa (@{$self->{'_filesofdir'}{$p}}) {
    TeXLive::TLUtils::push_uniq(\@files, $p . "/" . $aa);
  }
  if (defined($self->{'_subdirsofdir'}{$p})) {
    foreach my $sd (@{$self->{'_subdirsofdir'}{$p}}) {
      my @sdf = $self->files_under_path($p . "/" . $sd);
      TeXLive::TLUtils::push_uniq (\@files, @sdf);
    }
  }
  return @files;
}


#
# member access functions
#
sub svnroot {
  my $self = shift;
  if (@_) { $self->{'svnroot'} = shift };
  return $self->{'svnroot'};
}

sub revision {
  my $self = shift;
  if (@_) { $self->{'revision'} = shift };
  return $self->{'revision'};
}


sub architectures {
  my $self = shift;
  if (@_) { @{ $self->{'archs'} } = @_ }
  return exists $self->{'archs'} ? @{ $self->{'archs'} } : undef;
}


1;

### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #
