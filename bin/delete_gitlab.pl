#! /usr/bin/perl

use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin";
use AdminCreds qw($TOKEN);

my $debug = 0;

my $username = shift || '';

$username =~ s/^\s+//;
$username =~ s/\s+$//;

if ($username !~ /^\w+$/) {
    print "ERROR: User name missing $username\n";
    exit(1);
}
my $cmd_check = "curl -fsSk --header 'Private-Token: $TOKEN' https://gitlab.f5net.com/api/v4/users?username=$username";

my $userinfo = qx/$cmd_check/;
print "Command: $cmd_check\n" if($debug);
print "Output $userinfo\n" if($debug);

my $userid;
if ($userinfo =~ m/^\[\{"id":(\d+),/) {
    $userid = $1;
} else {
    print "ERROR: User not found: $username : $userinfo\n";
    exit(1);
}

my $cmd_delete = "curl -fsSk -X DELETE --header 'Private-Token: $TOKEN' https://gitlab.f5net.com/api/v4/users/$userid";
my $del_output = qx/$cmd_delete/;
print "Command: $cmd_delete\n" if($debug);
print "Output $del_output\n" if($debug);

if ($del_output =~ /error/i) {
    print "ERROR: User could not be deleted $username : $userid\n";
    exit(1);
} else {
    print "SUCCESS: User $username deleted\n";
}
