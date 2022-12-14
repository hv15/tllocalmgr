package TLLocalMgr::Arch;
use 5.010;
use base 'TeXLive::TLPDB';
use strict;
use warnings;
use List::MoreUtils qw/any none/;
use Carp;

my $SKIPPATTERN = qr{^(?:collection)-};


# TeXLive collections in the texlive-core package:
# (corresponds to the "medium scheme" of TeX Live)
my @core_colls = qw/
  basic
  context
  fontsrecommended
  langcjk
  langczechslovak
  langenglish
  langeuropean
  langfrench
  langgerman
  langitalian
  langpolish
  langportuguese
  langspanish
  latex
  latexrecommended
  luatex
  metapost
  plaingeneric
  xetex
  /;

# collections that are specific to texlive-core-doc:
my @core_doc_colls = qw(
);

# These are the other collections that define Arch Linux packages:
my @other_colls = qw(
    bibtexextra
    fontsextra
    formatsextra
    games
    humanities
    langchinese
    langcyrillic
    langgreek
    langjapanese
    langkorean
    latexextra
    music
    pictures
    pstricks
    publishers
    science
);

# We also have the collection texlive-langextra which is a meta-collection of
# the following upstream collections:
my @langextra_colls = qw(
    langarabic
    langother
);

my @core_additional = qw( bidi iftex pgf );
my @coredoc_additional = qw( bidi iftex pgf luatex pdftex );

sub collection_with_runfiles_pattern {
    my ($self, $coll, $pattern) = @_;
    $pattern = qr{$pattern};
    my @tmp;
    my $tlcoll = $self->get_package("collection-$coll");
    foreach my $d ($tlcoll->depends) {
        my $pkg = $self->get_package($d);
        my @runfiles = $pkg->runfiles;
        if ( any { $_ =~ /$pattern/ } @runfiles ) {
            push @tmp, $pkg->name
        }
    }
    return @tmp
}

sub collection_with_docfiles_pattern {
    my ($self, $coll, $pattern) = @_;
    $pattern = qr{$pattern};
    my @tmp;
    my $tlcoll = $self->get_package("collection-$coll");
    foreach my $d ($tlcoll->depends) {
        my $pkg = $self->get_package($d);
        my @docfiles = $pkg->docfiles;
        if ( any { $_ =~ /$pattern/ } @docfiles ) {
            push @tmp, $pkg->name
        }
    }
    return @tmp
}


sub archpackages {
    my $self = shift;
    my %tlpackages;

    push @{ $tlpackages{'core'} },     @core_additional;
    push @{ $tlpackages{'core'} },
        $self->collection_with_runfiles_pattern('binextra', 'texmf-dist|RELOC');
    push @{ $tlpackages{'core'} },
        $self->collection_with_runfiles_pattern('fontutils', 'texmf-dist|RELOC');
    push @{ $tlpackages{'core-doc'} }, @coredoc_additional;
    push @{ $tlpackages{'core-doc'} },
        $self->collection_with_docfiles_pattern('binextra', 'texmf-dist|RELOC');

    # We now produce the list of upstream packages that we put in
    # texlive-core:
    foreach my $coll (@core_colls) {
        my $tlpcoll = $self->get_package("collection-$coll")
            or croak "Can't get object for collection-$coll";
        foreach my $d ( $tlpcoll->depends ) {

            my $tlpdep   =  $self->get_package($d);
            my @runfiles =  $tlpdep->runfiles;
            my @docfiles =  $tlpdep->docfiles;
            push @docfiles, $tlpdep->srcfiles;
            # For texlive-core, avoid packages:
            # 1. whose name begin with bin- collection- or hyphen-
            # 2. without runfiles
            # 3. without runfiles under texmf-dist
            if ( $d !~ /$SKIPPATTERN/
                && @runfiles && any { $_ =~ m/texmf-dist|RELOC/ } @runfiles ) {
                push @{ $tlpackages{'core'} }, $d
            }
            # For texlive-core-doc, avoid packages:
            # 1. whose name begin with bin- collection- or hyphen-
            # 2. without docfiles
            # 3. without docfiles under texmf-dist
            if ( $d !~ /$SKIPPATTERN/
                && @docfiles && any { $_ =~ m/texmf-dist|RELOC/ } @docfiles ) {
                push @{ $tlpackages{'core-doc'} }, $d;
            }
        }
    }

    foreach my $coll (@core_doc_colls) {
        my $tlpcoll = $self->get_package("collection-$coll")
            or croak "Can't get object for collection-$coll";
        foreach my $d ( $tlpcoll->depends ) {
            push @{ $tlpackages{'core-doc'} }, $d
            unless $d =~ /$SKIPPATTERN/;
        }
    }

    foreach my $coll (@other_colls) {
        my $tlpcoll;
        if ($coll eq "science") {
            $tlpcoll = $self->get_package("collection-mathscience")
                or croak "Can't get object for collection-mathscience";
        } else {
            $tlpcoll = $self->get_package("collection-$coll")
                or croak "Can't get object for collection-$coll";
        }
        foreach my $d ( $tlpcoll->depends ) {
            my $tlpdep = $self->get_package($d);
            next if ( $coll =~ /^fontsextra/ and $d =~ /^(aleph|ocherokee|oinuit)$/ );
            next if ( $coll =~ /^pictures/ and $d eq 'pgf' );
            next if ( $coll =~ /^genericextra/ and $d eq 'iftex' );
            if ( $d eq 'ruhyphen' or $d eq 'ukrhyph' or
                 $d =~ /^hyphen-/ ) {
                 # Hyphen packages go to core.
                 push @{ $tlpackages{'core'} }, $d;
                 push @{ $tlpackages{"core-doc"} }, $d
                 if ( $tlpdep->doccontainerchecksum or $tlpdep->docsize );
                 next;
            }
            push @{ $tlpackages{$coll} }, $d
            unless $d =~ /$SKIPPATTERN/;
            if (
                ( $tlpdep->doccontainerchecksum
                    or $tlpdep->docsize )
                and $d !~ /$SKIPPATTERN/
            )
            {
                push @{ $tlpackages{"$coll-doc"} }, $d;
            }
        }
    }

    # Build texlive-langextra
    foreach my $coll (@langextra_colls) {
        my $tlpcoll = $self->get_package("collection-$coll")
            or croak "Can't get object for collection-$coll";
        foreach my $d ( $tlpcoll->depends ) {
            next if ( $d =~ /^(bidi|ebong)$/ ); # bidi is in core
            my $tlpdep = $self->get_package($d);
            if ( $d =~ /^hyphen-/ ) {
                 # Hyphen packages go to core.
                 push @{ $tlpackages{'core'} }, $d;
                 push @{ $tlpackages{"core-doc"} }, $d
                 if ( $tlpdep->doccontainerchecksum or $tlpdep->docsize );
                 next;
            }
            push @{ $tlpackages{'langextra'} }, $d
            unless $d =~ /$SKIPPATTERN/;
            if (
                ( $tlpdep->doccontainerchecksum
                    or $tlpdep->docsize )
                and $d !~ /$SKIPPATTERN/
               )
            {
                push @{ $tlpackages{"langextra-doc"} }, $d;
            }
        }
    }

    return %tlpackages
}

sub archversions {
    my $self = shift;
    my %tlpackages = $self->archpackages;
    my %versions;

    foreach my $coll ( keys %tlpackages ) {
        my @tmp;
        my $tlpkg = $self->get_package("collection-$coll");
        push @tmp, $tlpkg->revision if $tlpkg;
        foreach my $pkg ( @{ $tlpackages{$coll} } ) {
            my $tlpkg = $self->get_package($pkg) or croak "Can't get package $pkg: $!";
            #say "Looking for revision nr of package $pkg for $coll";
            push @tmp, $tlpkg->revision;
        }
        @tmp = sort { $a <=> $b } @tmp;
        $versions{$coll} = pop @tmp;
    }

    return %versions
}

sub archexecutes {
    my $self = shift;
    my %tlpackages = $self->archpackages;
    my %executes;

    foreach my $coll ( keys %tlpackages ) {
        my @tmp;
        foreach my $pkg ( @{ $tlpackages{$coll} } ) {
            my $tlpkg = $self->get_package($pkg);
            push @tmp, $tlpkg->executes if $tlpkg->executes;
        };
        # tex and latex-bin have no runfiles but have format lines
        if ( $coll eq "core" ) {
            foreach my $pkg ( qw/tex latex-bin/ ) {
                my $tlpkg = $self->get_package($pkg);
                push @tmp, $tlpkg->executes if $tlpkg->executes;
            };
        }
        $executes{$coll} = [@tmp];
    }

    return %executes
}

1;
