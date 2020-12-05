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

#$username =~ s/^(.)/$1./;

my $base_url = 'https://bugzilla.olympus.f5net.com';

my $url_login = $base_url . '/index.cgi?GoAheadAndLogIn=1';
my $url_search = $base_url . "/editusers.cgi?action=list&matchvalue=login_name&matchstr=$username&matchtype=substr&groupid=1&enabled_only=0";



my $mech = WWW::Mechanize->new();
$mech->cookie_jar(HTTP::Cookies->new());

$mech->get($url_login);

$mech->submit_form(
	form_name => 'login',
	fields => {
             Bugzilla_login => $ADMINUSER,
             Bugzilla_password => $ADMINPASS,
	}
);

$mech->get($url_search);

my $link = '';
$link = $mech->find_link(text_regex => qr/$username/i, url_regex => qr/^editusers\.cgi\?action=.*matchstr=$username/i);
#<a href="editusers.cgi?action=edit&amp;userid=3787&amp;matchtype=substr&amp;groupid=1&amp;grouprestrict=&amp;matchvalue=login_name&amp;matchstr=m.lam">
#Disabled - editusers.cgi?action=activity&amp;userid=2601&amp;matchtype=substr&amp;matchvalue=login_name&amp;grouprestrict=&amp;matchstr=uppuluri&amp;groupid=1
#Enabled -  editusers.cgi?action=activity&amp;userid=2601&amp;groupid=1&amp;grouprestrict=&amp;matchstr=uppuluri&amp;matchtype=substr&amp;matchvalue=login_name">

#https://bugzilla.olympus.f5net.com/editusers.cgi?action=list&matchvalue=login_name&matchstr=uppuluri&matchtype=substr&groupid=1

if(! $link) {
    print "ERROR: User could not be found: $username\n";
    exit(1);
}


$mech->get($link->url());

$mech->submit_form(
	form_number => 2,
	fields => {
             disabledtext => "User disabled",
             disable_mail => 1,
	}
);

print "SUCCESS: User disabled: $username\n";
exit(0);
