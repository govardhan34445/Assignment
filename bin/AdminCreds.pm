#! /usr/bin/perl

package AdminCreds;
use strict;
use warnings;

use constant PASSWORD_FILE => 'bin/creds.txt';
use Exporter;

our(@ISA) = 'Exporter';
our(@EXPORT_OK) = qw($ADMINUSER $ADMINPASS $TOKEN);

our ($ADMINUSER, $ADMINPASS, $TOKEN, $RBAPITOKEN);

my $debug = 0;

open(FH, '<', PASSWORD_FILE) or die "could not open file: PASSWORD_FILE: $!";

$ADMINUSER  = <FH>;
$ADMINPASS  = <FH>;
$TOKEN      = <FH>;

chomp $ADMINUSER;
chomp $ADMINPASS;
chomp $TOKEN;

print "U: $ADMINUSER, P: $ADMINPASS, T: $TOKEN\n" if($debug);

1;
