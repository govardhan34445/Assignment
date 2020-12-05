use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

use lib "../lib";
require AppUtils;

my $inactive  = 0;
my $user_name = 24;
my $password;
my $help;
my $update_pass;
GetOptions ("user_name=s" => \$user_name,
          "password=s"   => \$password,
          "inactive"     => \$inactive,
          "help"         => \$help,
          "update_pass"  => \$update_pass,
 ) || usage();
 
 
 sub usage {
    my $msg = join ("\n",
        "\n This script is used for adding or updating the user password",
        "\n\nUsage to create new user :-
            perl $0 --user_name 'myuser' --password 'my@123paSs#'
            
        To Update passowrd    
            perl $0 --user_name 'myuser' --password 'my@123paSs_NEW#' --update_pass

        To inactive user 
            perl $0 --user_name 'myuser' --inactive

        ",
        'Options:',
        '    --help        print this usage msg',
        '    --user_name   user_name to be added or for which password has to be updated',
        '    --update_pass use this flag while requesting the password update',
        '    --password  plain password to be created or updated',
        '    --inactive  flag to inactivate/delete the user',
    "\n");
    print $msg;
    exit 0;
}

usage() if ($help);
usage() unless ($user_name);
if (!$inactive) {
    usage() unless ($password);
}
my $util = AppUtils->new;

#update password
if ($update_pass) {
    $util->update_password($user_name,$password);
} elsif ($inactive) {
#incative /delete user
    $util->incative_user($user_name);
} else {
#create new user
    $util->create_user($user_name,$password);
}
