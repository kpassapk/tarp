#!perl  

use strict;
use Cwd;

=pod

This script changes \begin{Example}[x] tags which act as BOTH a beginTag and an
itemTag.  LaTexTract does not do that sort of thing so we will work around it
by putting in a dummy item tag immediately after every \begin{Example}.

    \begin{Example}[1]
    
becomes
    
    \begin{Example}[1]
    TECHARTS_DUMMY_ITEM_TAG-1

The script's behavior can be changed by editing exitemize.tas in the same
directory as the script.  Use

    perl exitemize.pl --gen-tas

to generate a compliant .tas file (not implemented yet!)

=cut

my $filename = qr/(?<!_itm)\.tex$/;

sub itemize {
    my $file = shift;
    
    my $f_itm = $file;
    $f_itm =~ s/\..*//;
    $f_itm .= "_itm.tex";
    
    unless ( $file =~ $filename ) {
        print "$file: skipped\n";
        return;
    }

    if ( -e $f_itm ) {
        print "$file: skipped ($f_itm exists)\n";
        return;
    }
    
    open TEX, "<$file" or die "Could not open '$file' for reading: $!, stopped";
    open ITM, ">", $f_itm
        or die "Could not open '$f_itm' for writing: $!, stopped";
    
    my $n = 0;
    
    while ( <TEX> ) {
        s/\r//;
        chomp;
        print ITM $_ . $/;
        if ( /\\begin{Example}\[(\d+)\]/ ) {
            print ITM "%TECHARTS_DUMMY_ITEM_TAG-($1)\n";
            $n++;
        }
    }
    close ITM;
    close TEX;
    
    print "$file: $n insertions";
    if ( $n ) {
        print " -> $f_itm\n";
    } else {
        unlink $f_itm;
        print "\n";
    }
    
}

if ( -e "exitemize.tas" ) {
    my $style_name = "_ItemizeStyle";
    open STY, '>', $style_name . ".pm" or die "Could not write to $style_name.pm: $!";
    print STY <<EOS;
package $style_name;
sub new { my \$class = shift; return bless \$class->SUPER::new(), \$class }
sub emptyFileContents {
    my \$self = shift;
    return \$self->SUPER::emptyFileContents() . <<EOT

filename = (?<!_itm)\.tex

EOT
}
sub constraints {
    my \$self = shift;
    my \$tas = shift;
    my \%c = \$self->SUPER::constraints( \$tas );
    \$c{filename} = Tarp::TAS::Spec->exists();
    return %c;
}

1;
EOS
    close STY;
    use Tarp::Style;
    Tarp::Style->import( $style_name );
    
    my $style = Tarp::Style->new();
    $style->load( "exitemize.tas" ) or die $style->errStr() . "\n";
    ( $filename ) = $style->qr( "filename" );
    
    unlink "$style_name.pm";
}

for ( <*> ) {
    next unless -f $_;
    itemize( $_ );
}
