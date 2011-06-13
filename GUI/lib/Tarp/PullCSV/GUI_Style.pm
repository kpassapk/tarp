package Tarp::PullCSV::GUI_Style;
use strict;

# When using the GUI, we enforce the existence of the "filename" entry.
# If it exists, we check RX syntax as usual but we also check that the contents
# match the value set in curFile (a class method).

my $curFile = '';

sub curFile {
    my $class = shift;
    if ( @_ ) {
        return $curFile = shift;
    } else {
        return $curFile;
    }
}

sub new {
    my $class = shift;
    my $self = bless $class->SUPER::new(), $class;
    return $self;
}

sub emptyFileContents {
    my $self = shift;
    my $s = $self->SUPER::emptyFileContents();
    return $s . <<END_OF_TAS;
filename = .*

END_OF_TAS
}

sub constraints {
    my $self = shift;
    my $tas = shift;
    my %c = $self->SUPER::constraints( $tas );
    
    # if it's not there already, report it is missing.
    $c{filename} ||= Tarp::TAS::Spec->exists();
    
    # Note we don't use the first argument because this one is a stripped
    # regular expression with the variable names as nc bufs but without the
    # values.  Instead, we feed in the interpolated regexp as a third argument.
    # The second argument is the current filename.
    
    sub filenameMatches {
        shift;
        my $f = shift;
        my $v = shift;

        foreach ( @$v ) {
            if ( $f =~ /$_/ ) {
                return ();
            }
        }
        return "does not match '$f'"
    }
    
    # Report if it does not match the current filename.
    $c{filename} = Tarp::TAS::Spec->multi(
        $c{filename},
        [ \&filenameMatches, $curFile, $tas->interpolate( "filename" ) ],
    );
    return %c;
}

1;
