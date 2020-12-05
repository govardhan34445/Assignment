package F5CM::LDAP;
use strict;
use warnings;

use Net::LDAPS;

#default value constants
my $DEFAULT_LDAP_SERVER = "ldaps.olympus.f5net.com";
my $DEFAULT_BASE = "dc=olympus,dc=f5net,dc=com";
my $DEFAULT_ATTRIBUTES = [
    'cn', 'l', 'title', 'UserAccountControl',
    'mail', 'department', 'manager', 'displayName',
    'mailNickname', 'sAMAccountName' ];
our %LDAP_AUTH;
my $LDAP_CREDS_FILE = 'ldap_bind_creds';
my $HOME_CM_DIR = $ENV{"HOME"}."/.cm";

if ( -f "$HOME_CM_DIR/$LDAP_CREDS_FILE") {
    die "Unable to load credentials from $HOME_CM_DIR/$LDAP_CREDS_FILE" unless do "$HOME_CM_DIR/$LDAP_CREDS_FILE";
} else {
    die "Unable to load credentials" unless do "/etc/f5cm/$LDAP_CREDS_FILE";
}

my $DEFAULT_USER = $LDAP_AUTH{'user'};
my $DEFAULT_PASSWORD = $LDAP_AUTH{'password'};

#initialize variables
my $ldap_server = $DEFAULT_LDAP_SERVER;
my $base = $DEFAULT_BASE;
my $attributes = $DEFAULT_ATTRIBUTES;

sub getLDAPServer {
    return $ldap_server;
}

sub getBaseDN {
    return $base;
}

sub init {
    my ($self, $user, $password) = @_;

    if (!$user) { $user = $DEFAULT_USER; }
    if (!$password) { $password = $DEFAULT_PASSWORD; }
    print "LDAP: $user, $password\n";

    my $ldap = Net::LDAPS->new(
        $ldap_server, verify=>'none'
    ) or die "Can not connect to AD server - please try again later.\n";

    my $mesg = $ldap->bind("$user\@olympus.f5net.com", password=> $password);
    if ( $mesg->code() ) {
        print "bind failure:", $mesg->error, "\n";
        return 0;
    }

    return 1;
}

#Based on LDAPSearch in add_p4_user
sub search {
    my ($ldap,$search_string,$attributes,$base) = @_;
    my $result = 0;

    if ( !$base ) { $base = $DEFAULT_BASE; }
    
    if ( !$attributes ) { $attributes = $DEFAULT_ATTRIBUTES; }

    $result = $ldap->search(
            base    => "$base",
            #TODO: Check this and make sure it's constant
            scope   => "sub",
            filter  => "$search_string",
            attrs   => $attributes,
        );
    if ( $result->code() ) {
        print "ERROR: Search failure:", $result->error, "\n";
    }

    return $result;
}

