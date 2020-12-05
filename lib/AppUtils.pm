package AppUtils;

use strict;
use warnings;

use Dancer2;
use F5CM::LDAP;

sub new {
    bless( {}, shift );
}

sub validate_credential {
    my $self = shift;
    my $user = shift || undef;
    my $pass = shift || undef;

    my $ldap = F5CM::LDAP->init($user, $pass);

    print "valid: $ldap\n";
    my $valid = ($ldap) ? 1 : 0;

    return ( $user, $valid );
}

1;

