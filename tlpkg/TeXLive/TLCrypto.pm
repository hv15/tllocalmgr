# $Id: TLCrypto.pm 46745 2018-02-26 18:16:54Z karl $
# TeXLive::TLcrypto.pm - handle checksums and signatures.
# Copyright 2016-2018 Norbert Preining
# This file is licensed under the GNU General Public License version 2
# or any later version.

package TeXLive::TLCrypto;

use Digest::MD5;

use TeXLive::TLConfig;
use TeXLive::TLUtils qw(debug ddebug win32 which platform conv_to_w32_path tlwarn tldie);


my $svnrev = '$Revision$';
my $_modulerevision = ($svnrev =~ m/: ([0-9]+) /) ? $1 : "unknown";
sub module_revision { return $_modulerevision; }

=pod

=head1 NAME

C<TeXLive::TLCrypto> -- checksums and cryptographic signatures

=head1 SYNOPSIS

  use TeXLive::TLCrypto;  # requires Digest::MD5 and Digest::SHA

=head2 Setup

  TeXLive::TLCrypto::setup_checksum_method();

=head2 Checksums

  TeXLive::TLCrypto::tlchecksum($path);
  TeXLive::TLCrypto::verify_checksum($file, $url);

=head2 Signatures

  TeXLive::TLCrypto::setup_gpg();
  TeXLive::TLCrypto::verify_signature($file, $url);

=head1 DESCRIPTION

=cut

BEGIN {
  use Exporter ();
  use vars qw(@ISA @EXPORT_OK @EXPORT);
  @ISA = qw(Exporter);
  @EXPORT_OK = qw(
    &tlchecksum
    &tl_short_digest
    &verify_checksum
    &setup_gpg
    &verify_signature
    %VerificationStatusDescription
    $VS_VERIFIED $VS_CHECKSUM_ERROR $VS_SIGNATURE_ERROR $VS_CONNECTION_ERROR
    $VS_UNSIGNED $VS_GPG_UNAVAILABLE $VS_PUBKEY_MISSING $VS_UNKNOWN
  );
  @EXPORT = qw(
    %VerificationStatusDescription
    $VS_VERIFIED $VS_CHECKSUM_ERROR $VS_SIGNATURE_ERROR $VS_CONNECTION_ERROR
    $VS_UNSIGNED $VS_GPG_UNAVAILABLE $VS_PUBKEY_MISSING $VS_UNKNOWN
  );
}

=pod

=item C<< setup_checksum_method() >>

Tries to find a checksum method: check usability of C<Digest::SHA>,
then the programs C<openssl>, C<sha512sum>, and C<shasum>, in that
order.  On old-enough Macs, C<openssl> is present but does not have
the option C<-sha512>, while the separate program C<shasum> does suffice.

Returns the checksum method as a string, and also sets
C<<$::checksum_method>>, or false if none found.

=cut

sub setup_checksum_method {
  # make it a noop if already defined
  # the checksum method could also be "" meaning that there
  # is none. We do not need to check again. Thus we check
  # on defined.
  return ($::checksum_method) if defined($::checksum_method);
  # default is no checksum
  $::checksum_method = "";
  # for debugging
  # $::checksum_method = "sha512sum";
  # return($::checksum_method);
  # try to load Digest::SHA, and if that fails, use our own slow modules
  eval { 
    require Digest::SHA;
    Digest::SHA->import('sha512_hex');
    debug("Using checksum method digest::sha\n");
    $::checksum_method = "digest::sha";
  };
  if ($@ && ($^O !~ /^MSWin/i)) {
    # for unix like environments we test other programs (openssl, sha512sum,
    # shasum), too
    my $ret;

    # first for openssl dgst -sha512
    # old MacOS openssl does not support -sha512!
    $ret = system("openssl dgst -sha512 >/dev/null 2>&1 </dev/null" );
    if ($ret == 0) {
      debug("Using checksum method openssl\n");
      return($::checksum_method = "openssl");
    }

    # next for sha512sum, but this is not available on old MacOS
    if (TeXLive::TLUtils::which("sha512sum")) {
      debug("Using checksum method sha512sum\n");
      return($::checksum_method = "sha512sum");
    }

    # shasum for old Macs
    $ret = system("shasum -a 512 >/dev/null 2>&1 </dev/null" );
    if ($ret == 0) {
      debug("Using checksum method shasum\n");
      return($::checksum_method = "shasum");
    }

    debug("Cannot find usable checksum method!\n");
  }
  return($::checksum_method);
}


=pod

=item C<< tlchecksum($file) >>

Return checksum of C<$file>.

=cut

sub tlchecksum {
  my ($file) = @_;
  # this is here for the case that a script forgets to
  # set up the checksum method!
  if (!$::checksum_method) {
    setup_checksum_method();
  }
  tldie("no checksum method available\n") if (!$::checksum_method);
  if (-r $file) {
    my ($out, $ret);
    if ($::checksum_method eq "openssl") {
      ($out, $ret) = TeXLive::TLUtils::run_cmd("openssl dgst -sha512 $file");
      chomp($out);
    } elsif ($::checksum_method eq "sha512sum") {
      ($out, $ret) = TeXLive::TLUtils::run_cmd("sha512sum $file");
      chomp($out);
    } elsif ($::checksum_method eq "shasum") {
      ($out, $ret) = TeXLive::TLUtils::run_cmd("shasum -a 512 $file");
      chomp($out);
    } elsif ($::checksum_method eq "digest::sha") {
      open(FILE, $file) || die "open($file) failed: $!";
      binmode(FILE);
      $out = Digest::SHA->new(512)->addfile(*FILE)->hexdigest;
      close(FILE);
      $ret = 0;
    } else {
      tldie("unknown checksum program: $::checksum_method\n");
    }
    if ($ret != 0) {
      tlwarn("tlchecksum: cannot compute checksum: $file\n");
      return "";
    }
    ddebug("tlchecksum: out = $out\n");
    my $cs;
    if ($::checksum_method eq "openssl") {
      (undef,$cs) = split(/= /,$out);
    } elsif ($::checksum_method eq "sha512sum") {
      ($cs,undef) = split(' ',$out);
    } elsif ($::checksum_method eq "shasum") {
      ($cs,undef) = split(' ',$out);
    } elsif ($::checksum_method eq "digest::sha") {
      $cs = $out;
    }
    debug("tlchecksum($file): ===$cs===\n");
    if (length($cs) != 128) {
      tlwarn("unexpected output from $::checksum_method: $out\n");
      return "";
    }
    return $cs;
  } else {
    tlwarn("tlchecksum: given file not readable: $file\n");
    return "";
  }
}

# sub tlchecksum {
#   my ($file) = @_;
#   if (-r $file) {
#     open(FILE, $file) || die "open($file) failed: $!";
#     binmode(FILE);
#     my $cshash = $dig->new(512)->addfile(*FILE)->hexdigest;
#     close(FILE);
#     return $cshash;
#   } else {
#     tlwarn("tlchecksum: given file not readable: $file\n");
#     return "";
#   }
# } 

=pod

=item C<< tl_short_digest($str) >>

Return short digest (MD5) of C<$str>.

=cut

sub tl_short_digest { return (Digest::MD5::md5_hex(shift)); }

# emacs-page
=pod

=item C<< verify_checksum($file, $checksum_url) >>

Verifies that C<$file> has checksum C<$checksum_url>, and if gpg is
available also verifies that the checksum is signed.

Returns 
C<$VS_VERIFIED> on success, 
C<$VS_CONNECTION_ERROR> on connection error,
C<$VS_UNSIGNED> on missing signature file, 
C<$VS_GPG_UNAVAILABLE> if no gpg program is available,
C<$VS_PUBKEY_MISSING> if the pubkey is not available, 
C<$VS_CHECKSUM_ERROR> on checksum errors,and 
C<$VS_SIGNATURE_ERROR> on signature errors.
In case of errors returns an informal message as second argument.

=cut

sub verify_checksum {
  my ($file, $checksum_url) = @_;
  # don't do anything if we cannot determine a checksum method
  # return -2 which is as much as missing signature
  return($VS_UNSIGNED) if (!$::checksum_method);
  my $checksum_file
    = TeXLive::TLUtils::download_to_temp_or_file($checksum_url);

  # next step is verification of tlpdb checksum with checksum file
  # existenc of checksum_file was checked above
  if (!$checksum_file) {
    debug("verify_checksum: download did not succeed for $checksum_url\n");
    return($VS_CONNECTION_ERROR, "download did not succeed: $checksum_url");
  }
  # check the signature
  my ($ret, $msg) = verify_signature($checksum_file, $checksum_url);

  if ($ret != 0) {
    debug("verify_checksum: returning $ret and $msg\n");
    return ($ret, $msg)
  }

  # verify local data
  open $cs_fh, "<$checksum_file" or die("cannot read file: $!");
  if (read ($cs_fh, $remote_digest, $ChecksumLength) != $ChecksumLength) {
    close($cs_fh);
    debug("verify_checksum: incomplete read from\n  $checksum_file\nfor\n  $file\nand\n  $checksum_url\n");
    return($VS_CHECKSUM_ERROR, "incomplete read from $checksum_file");
  } else {
    close($cs_fh);
    debug("verify_checksum: found remote digest\n  $remote_digest\nfrom\n  $checksum_file\nfor\n  $file\nand\n  $checksum_url\n");
  }
  $local_digest = tlchecksum($file);
  debug("verify_checksum: local_digest = $local_digest\n");
  if ($local_digest ne $remote_digest) {
    return($VS_CHECKSUM_ERROR, "digest disagree");
  }

  # we are still here, so checksum also succeeded
  debug("checksum of local copy identical with remote hash\n");

  return(0);
}

# emacs-page
=pod

=item C<< setup_gpg() >>

Tries to set up gpg command line C<$::gpg> used for verification of
downloads. Checks for the environment variable C<TL_GNUPG>; if that
envvar is not set, first C<gpg>, then C<gpg2>, then, on Windows only,
C<tlpkg/installer/gpg/gpg.exe> is looked for.  Further adaptation of the
invocation of C<gpg> can be done using the two enviroment variables
C<TL_GNUPGHOME>, which is passed to C<gpg> with C<--homedir>, and
C<TL_GNUPGARGS>, which replaces the default arguments
C<--no-secmem-warning --no-permission-warning>.

Returns 1/0 on success/failure.

=cut

sub setup_gpg {
  my $master = shift;
  my $found = 0;
  my $prg;
  if ($ENV{'TL_GNUPG'}) {
    # if envvar is set, don't look for anything else.
    $prg = test_one_gpg($ENV{'TL_GNUPG'});
    $found = 1 if ($prg);
  } else {
    # no envvar, look for gpg
    $prg = test_one_gpg('gpg');
    $found = 1 if ($prg);
  
    # no gpg, look for gpg2
    if (!$found) {
      $prg = test_one_gpg('gpg2');
      $found = 1 if ($prg);
    }
    if (!$found) {
      # test also a shipped version from tlgpg
      my $p = "$master/tlpkg/installer/gpg/gpg." .
        ($^O =~ /^MSWin/i ? "exe" : platform()) ;
      debug("Testing for gpg in $p\n");
      if (-r $p) {
        if ($^O =~ /^MSWin/i) {
          $prg = conv_to_w32_path($p);
        } else {
          $prg = "\"$p\"";
        }
        $found = 1;
      }
    }
  }
  return 0 if (!$found);

  # $prg is already properly quoted!

  # ok, we found one
  # Set up the gpg invocation:
  my $gpghome = ($ENV{'TL_GNUPGHOME'} ? $ENV{'TL_GNUPGHOME'} : 
                                        "$master/tlpkg/gpg" );
  $gpghome =~ s!/!\\!g if win32();
  my $gpghome_quote = "\"$gpghome\"";
  # mind the final space for following args
  $::gpg = "$prg --homedir $gpghome_quote ";
  #
  # check for additional keyring
  # originally we wanted to use TEXMFSYSCONFIG, but gnupg on Windows
  # is so stupid that it *prepends* GNUPGHOME to paths starting with
  # a drive letter like c:/
  # Thus we switch to using repository-keys.gpg in GNUPGHOME!
  my $addkr = "$gpghome/repository-keys.gpg";
  if (-r $addkr) {
    debug("setup_gpg: using additional keyring $addkr\n");
    $::gpg .= "--keyring repository-keys.gpg ";
  }
  if ($ENV{'TL_GNUPGARGS'}) {
    $::gpg .= $ENV{'TL_GNUPGARGS'};
  } else {
    $::gpg .= "--no-secmem-warning --no-permission-warning --lock-never ";
  }
  debug("gpg command line: $::gpg\n");
  return 1;
}

sub test_one_gpg {
  my $prg = shift;
  my $cmdline;
  debug("Testing for gpg in $prg\n");
  if ($^O =~ /^MSWin/i) {
    # Perl on Windows somehow does not allow calling a program
    # without a full path - at least a call to "gpg" tells me
    # that "c:/Users/norbert/gpg" is not recognized ...
    # consequence - use which!
    $prg = which($prg);
    return "" if (!$prg);
    $prg = conv_to_w32_path($prg);
    $cmdline = "$prg --version >nul 2>&1";
  } else {
    $cmdline = "$prg --version >/dev/null 2>&1";
  }
  my $ret = system($cmdline);
  if ($ret == 0) {
    debug(" ... gpg ok! [$cmdline]\n");
    return $prg;
  } else {
    debug(" ... gpg not ok! [$cmdline]\n");
    return "";
  }
}

# emacs-page
=pod

=item C<< verify_signature($file, $url) >>

Verifies a download of C<$url> into C<$file> by cheking the 
gpg signature in C<$url.asc>.

Returns 
$VS_VERIFIED on success, 
$VS_UNSIGNED on missing signature file, 
$VS_SIGNATURE_ERROR on signature error,
$VS_GPG_UNAVAILABLE if no gpg is available, and 
$VS_PUBKEY_MISSING if a pubkey is missing.
In case of errors returns an informal message as second argument.

=cut

sub verify_signature {
  my ($file, $url) = @_;
  my $signature_url = "$url.asc";

  # if we have $::gpg set, we try to verify cryptographic signatures
  if ($::gpg) {
    my $signature_file
      = TeXLive::TLUtils::download_to_temp_or_file($signature_url);
    if ($signature_file) {
      my ($ret, $out) = gpg_verify_signature($file, $signature_file);
      if ($ret == 1) {
        # no need to show the output
        debug("cryptographic signature of $url verified\n");
        return($VS_VERIFIED);
      } elsif ($ret == -1) {
        return($VS_PUBKEY_MISSING, $out);
      } else {
        return($VS_SIGNATURE_ERROR, <<GPGERROR);
cryptographic signature verification of
  $file
against
  $signature_url
failed. Output was
$out
Please report to texlive\@tug.org
GPGERROR
      }
    } else {
      debug("no access to cryptographic signature $signature_url\n");
      return($VS_UNSIGNED, "no access to cryptographic signature");
    }
  } else {
    debug("gpg prog not defined, no checking of signatures\n");
    # we return 0 (= success) if not gpg is available
    return($VS_GPG_UNAVAILABLE, "no gpg available");
  }
  # not reached
  return ($VS_UNKNOWN);
}

=pod

=item C<< gpg_verify_signature($file, $sig) >>

Internal routine running gpg to verify signature C<$sig> of C<$file>.

=cut

sub gpg_verify_signature {
  my ($file, $sig) = @_;
  my ($file_quote, $sig_quote);
  if (win32()) {
    $file =~ s!/!\\!g;
    $sig =~ s!/!\\!g;
  }
  $file_quote = TeXLive::TLUtils::quotify_path_with_spaces ($file);
  $sig_quote = TeXLive::TLUtils::quotify_path_with_spaces ($sig);
  my ($status_fh, $status_file) = TeXLive::TLUtils::tl_tmpfile();
  close($status_fh);
  my ($out, $ret)
    = TeXLive::TLUtils::run_cmd("$::gpg --status-file \"$status_file\" --verify $sig_quote $file_quote 2>&1");
  if ($ret == 0) {
    debug("verification succeeded, output:\n$out\n");
    return (1, $out);
  } else {
    open($status_fd, "<", $status_file) || die("Cannot open status file: $!");
    while (<$status_fd>) {
      if (m/^\[GNUPG:\] NO_PUBKEY (.*)/) {
        close($status_fd);
        debug("missing pubkey $1\n");
        return (-1, "missing pubkey $1");
      }
    }
    return (0, $out);
  }
}

=pod

=item C<< %VerificationStatusDescription >>

Provides a textual representation for the verification status values.

=cut

our $VS_VERIFIED = 0;
our $VS_CHECKSUM_ERROR = 1;
our $VS_SIGNATURE_ERROR = 2;
our $VS_CONNECTION_ERROR = -1;
our $VS_UNSIGNED = -2;
our $VS_GPG_UNAVAILABLE = -3;
our $VS_PUBKEY_MISSING = -4;
our $VS_UNKNOWN = -100;

our %VerificationStatusDescription = (
  $VS_VERIFIED         => 'verified',
  $VS_CHECKSUM_ERROR   => 'checksum error',
  $VS_SIGNATURE_ERROR  => 'signature error',
  $VS_CONNECTION_ERROR => 'connection error',
  $VS_UNSIGNED         => 'unsigned',
  $VS_GPG_UNAVAILABLE  => 'gpg unavailable',
  $VS_PUBKEY_MISSING   => 'pubkey missing',
  $VS_UNKNOWN          => 'unknown',
);

=back
=cut

1;
__END__

=head1 SEE ALSO

The modules L<TeXLive::Config>, L<TeXLive::TLUtils>, etc.,
and the documentation in the repository: C<Master/tlpkg/doc/>.
Also the standard modules L<Digest::MD5> and L<Digest::SHA>.

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
