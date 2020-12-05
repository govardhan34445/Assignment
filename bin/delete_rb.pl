#! /usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use FindBin;

use lib "$FindBin::Bin";
use AdminCreds qw($ADMINUSER $ADMINPASS);

#use LWP::ConsoleLogger::Everywhere ();
use WWW::Mechanize;

my $debug = 0;

# Get username from commandline and validate
my $username = shift || '';
$username =~ s/^\s+//;
$username =~ s/\s+$//;

if ($username !~ /^\w+$/) {
    print "ERROR: User name missing $username\n";
    exit(1);
}

my $base_url = 'https://reviewboard.olympus.f5net.com';

my $url_login = $base_url . '/account/login/?next_page=/r/search/';
my $url_search = $base_url . '/admin/db/auth/user/?q=' . $username;

my $mech = WWW::Mechanize->new();
$mech->cookie_jar(HTTP::Cookies->new());

$mech->get($url_login);

$mech->submit_form(
	form_number => 2,
	fields => {
             username => $ADMINUSER,
             password => $ADMINPASS,
	}
);

$mech->get($url_search);

my $link = '';
$link = $mech->find_link(text_regex => qr/^disabled\.$username$/);

if($link) {
    print "ERROR: User is already disabled: $username\n";
    exit(1);
}

$link = $mech->find_link(text_regex => qr/^$username$/);

if(! $link) {
    print "ERROR: User could not be found: $username\n";
    exit(1);
}

#open FH, '>', 'out' or die "Could not open out: $!";
#print FH Dumper $link;
#print FH $mech->content();

$username = "disable.$username";
#$mech->follow_link(text_regex => qr/^$username$/, n => 1);
#$mech->follow_link($link);
$mech->get($link->url());

$mech->submit_form(
	form_number => 2,
	fields => {
             username => "$username",
	}
);

print "SUCCESS: User disabled: $username\n";
exit(0);
