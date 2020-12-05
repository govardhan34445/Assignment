package Api::View;

use strict;
use warnings;
use List::MoreUtils qw(uniq);
use Dancer2;
use DBI;
use LWP::UserAgent ();
use FindBin;
use MIME::Base64 qw(encode_base64);
use lib "$FindBin::Bin";
use AdminCreds qw($ADMINUSER $ADMINPASS);

#use Dancer2::Plugin::Database;
#use base qw(CMAdmin);

use IPC::Run qw(run timeout);
use Data::Dumper;

# RB API auth-token
my $auth_token = 'Basic ' . encode_base64("$ADMINUSER:$ADMINPASS");
my $base_url = 'https://reviewboard.olympus.f5net.com';

sub new {
    my($self, @params) = @_;
    print "PARAMS: @params\n";
    bless ({@params},$self);
}


sub mgr_view {
    my($self, $user_name) = @_;
    my $result = '';

    if ($user_name) {
	#$result = qx!cat bin/mgr.txt!;
	$result = `mgr_view -u $user_name`;
    }

    my @result = split(/\n\n/, $result);

    my @top = split(/\n/, $result[0]);
    shift @top if ($top[0] =~ /^\s*$/); # lose blank line

    my @mid = split(/\n/, $result[1]);
    shift @mid if ($mid[0] =~ /ERROR/); # lose ERROR line

    my @bot = split(/\n/, $result[2]);
    shift @bot if ($bot[0] =~ /P4 Groups/); # lose header line

    my @middle;
    foreach my $line (@mid) {
        #push @middle, [ map{ s/^\s+//; s/\s+$//; "&nbsp;$_&nbsp;" } unpack('a20 a35 a11 a*', $line) ];
	#    adapa           Praveen Kumar Reddy ADAPA           HYDERABAD  Software Engineer I
        $line =~ s/^\s+/ /;
        push @middle, $line; 
    }

    my @bottom = parse_p4_groups_output(@bot);

    return ([\@top, \@middle, \@bottom], '');
}

sub parse_p4_groups_output {
    my (@bot) = @_;

    my (@bottom, %groups, @groups);
    foreach my $line (@bot) {
        my ($b, $s, $rest) = map{ s/^\s+//; s/\s+$//; $_ ? $_ : ' '} unpack('a2 a2 a*', $line);
        #X X glikman              cm           superusers test

        my ($user, @grps) = map{ s/^\s+//; s/\s+$//; $_} split(/ +/, $rest);

        foreach my $group (@grps) {
            $groups{$group} = 1;
        }

        #print "Cols: $b, $s, $user => ", join(':', @grps), ", G: ", join(':', sort keys %groups), "\n";

	push @bottom, [ $b, $s, $user ];
	push @groups, \@grps;
    }

    for (my $i = 0; $i <= $#bottom; $i++) {
        foreach my $group (sort keys %groups) {
            push @{$bottom[$i]}, grep(/^$group$/, @{$groups[$i]}) ? $group : ' ';
        }
        #print "Bottom: ", join(':', @{$bottom[$i]}), "\n";
    }
    return @bottom;
}

sub get_add_user_form {
    my($self) = @_;

    #  my $result = `p4 print //depot/auth/allowed-groups`;

     #my $result = `cat /home/reknar/UI/live/CMADMIN-SUS/CMAdmin/t/test.txt`;
     my $result = `cat t/test.txt`;

     # $result = [ uniq (split ("\n",$result))];

     $result = [  (split ("\n",$result))];

    return $result;
}


sub add_user {
    my ($self,$params) = @_;
    my $group;

    debug 'add_user: params: ', Dumper($params), "\n";

    my @groups = ref ($params->{'groups[0][]'}) ? 
		    @{$params->{'groups[0][]'}} : # multiple groups selected
                    ( $params->{'groups[0][]'} ); # single group selected

    debug 'add_user: groups: ', Dumper(\@groups), "\n";

    foreach (uniq @groups) {
        chomp;
        $group .= $_.' ';
    }
    my $user_name = $params->{username};
    my $skip_mgr  = $params->{skip_manager};
    print "/home/reknar/cmscripts/add_p4_user --user_name $user_name --skip_manager $skip_mgr --group $group\n";
    
    my $error = 0;
    my $result;
        eval {
            $result = `/home/reknar/cmscripts/add_p4_user --user_name $user_name --skip_manager $skip_mgr --group "$group"`;
        };
    if ($@) {
        $error = 1;
    } 
    elsif ($result =~ /could not/) {
        print "ERROR: Matched could not\n";
        $error = 1;
    }

    print "R: $result\n";
    chomp($result);
    return ($result, $error);
}

sub review_grp_add_user {
    my ($self, $params) = @_;

    my $ua = LWP::UserAgent->new();

    my $grp_name = $params->{group_name};
    my $username = $params->{username};
    my $result;
    my $error = 0;

    my $url = $base_url . "/api/groups/$grp_name/users/";
    my $payload = "username=$username";

    eval {
        my $response = $ua->post($url,
            authorization => $auth_token,
            Content_Type => 'application/x-www-form-urlencoded',
            Content => $payload
        );

        $result = decode_json($response->decoded_content);
        
        if( (defined $result->{stat}) && ($result->{stat} eq 'fail') ) {
            $error = 1;
        }
    };
    if($@) {
        $result = $@;
        $error = 1;
    };

    return ($result, $error);
}

sub review_grp_remove_user {
    my ($self, $params) = @_;

    my $ua = LWP::UserAgent->new();

    my $grp_name = $params->{group_name};
    my $username = $params->{username};
    my $result;
    my $error = 0;

    my $url = $base_url . "/api/groups/$grp_name/users/$username/";
    my $payload = "";

    eval {
        my $response = $ua->delete($url,
            authorization => $auth_token,
            Content_Type => 'application/x-www-form-urlencoded',
            Content => $payload
        );

        if( $response && $response->decoded_content ) {
            $result = decode_json($response->decoded_content);
            if( (defined $result->{stat}) && ($result->{stat} eq 'fail') ) {
                $error = 1;
            } 
        } else {
            $result = 1;
        }
    };
    if($@) {
        $result = $@;
        $error = 1;
    };

    return ($result, $error);
}

sub f5ldap_check {
    my ($self, $user_name) = @_;

    my ($in1, $out1, $err1);
    my ($in2, $out2, $err2);
    my @cmd1 = ('f5ldap', $user_name);
    my @cmd2 = ('f5ldap', '-t', $user_name);
    print "C: @cmd1\n";
    eval {
        run \@cmd1, \$in1, \$out1, \$err1, timeout( 20 ) or die "cat: $?"
    };
    if ($@) {
        print "Error: $@\n";
    }
    print "C: @cmd2\n";
    eval {
        run \@cmd2, \$in2, \$out2, \$err2, timeout( 20 ) or die "cat: $?"
    };
    if ($@) {
        print "Error: $@\n";
    }

    print "I: $in1, O: $out1, E: $err1\n";
    print "I: $in2, O: $out2, E: $err2\n";
    my $out = $out1 . "\n" . $out2;
    my $err = $err1 . "\n" . $err2 if($err1 or $err2);
    return ($out, $err);
}
sub delete_user_git {
    my ($self, $user_name, $ticket) = @_;

    my ($in, $out, $err);
  
    return ('', 'Ticket# is missing') unless ($ticket);

    my $status = 'PASS';
    #my @cmd = ('bin/f5ldap');
    my @cmd = ('/usr/bin/perl', 'bin/delete_gitlab.pl', "$user_name");
    print "C: @cmd\n";
    eval {
        run \@cmd, \$in, \$out, \$err, timeout( 20 ) or die "cat: $?"
    };
    if ($@) {
        print "Error: $@\n";
        $status = 'FAIL'; 
    }

    print "I: $in, O: $out, E: $err\n";

    $self->log_activity($user_name, $ticket, \@cmd, $out, $err, $status);

    return ($out, $err);
}
sub cleanup_build {
    my ($self, $user_name) = @_;

    my ($in, $out, $err);
    #my @cmd = ('bash', '-x', 'bin/f5ldap');
    my @cmd = ('sudo', '/cmscripts/cleanup_builds', '-g', '800', '-m', $user_name, '-a', '-y');
    print "C: @cmd\n";
    eval {
        run \@cmd, \$in, \$out, \$err, timeout( 120 ) or die "cat: $?"
    };
    if ($@) {
        print "Error: $@\n";
    }

    print "I: $in, O: $out, E: $err\n";
    return ($out, $err);
}
sub delete_user_p4_remove {
    my ($self, $user_name, $ticket, $delete, $force) = @_;

    my $info = $self->get_activity($user_name);
    my @pending = $self->check_activity($user_name); # if($delete);

    return ('', 'Ticket# is missing') unless ($ticket);

    my ($in, $out, $err);

    #my @cmd = ('bash', '-x', 'bin/f5ldap');
    my @cmd = ('/cmscripts/p4_delete_user.py', '--user', $user_name);
    print "C: @cmd\n";

    if ($delete and ($#pending == -1 or $force)) {
        eval {
            run \@cmd, \$in, \$out, \$err, timeout( 60 ) or die "cat: $?"
        };
        if ($@) {
            $err = $@;
            print "Error: $@\n";
        }

        my @err = split(/\n/, $err);
        $err .= $err[$#err];

        $out = 'SUCCESS: User removed' if (! $err);
        $self->log_activity($user_name, $ticket, \@cmd, $out, $err, $err ? 'FAIL' : 'PASS');
        print "I: $in, O: $out, E: $err\n";

    } 

    return ($out, $err, $info, \@pending);
}
sub delete_user_p4_audit {
    my ($self, $user_name, $ticket, $delete_type, $force) = @_;

    my $info = $self->get_activity($user_name);
    my @pending = $self->check_activity($user_name) if($delete_type);

    return ('', 'Ticket# is missing') unless ($ticket);

    my ($in, $out, $err);
    #my @cmd = ('bash', '-x', 'bin/f5ldap');
    my @cmd = ('/bin/bash', 'bin/audit_users.sh', $user_name);
    if ($delete_type eq 'dir') {
	    push(@cmd, 'delete_dir');
    } elsif ($delete_type eq 'cl') {
	    push(@cmd, 'delete_cl');
    }
    print "C: @cmd\n";

    if ($#pending == -1 or $force) {
        eval {
            run \@cmd, \$in, \$out, \$err, timeout( 300 ) or die "Error: $?"
        };
        if ($@) {
            print "Error: $@\n";
        }
        $self->log_activity($user_name, $ticket, \@cmd, $out, $err, $err ? 'FAIL' : 'PASS');
    }

    print "I: $in, O: $out, E: $err, Info: @$info\n";

    return ($out, $err, $info, \@pending);
}
sub delete_user_bugz {
    my ($self, $user_name, $ticket) = @_;

    my ($in, $out, $err);

    return ('', 'Ticket# is missing') unless ($ticket);

    my $status = 'PASS';
    #my @cmd = ('bin/f5ldap');
    my @cmd = ('/usr/bin/perl', 'bin/delete_bugz.pl', $user_name);
    print "C: @cmd\n";
    eval {
        run \@cmd, \$in, \$out, \$err, timeout( 20 ) or die "cat: $?"
    };
    if ($@) {
        print "Error: $@\n";
        $status = 'FAIL'; 
    }

    print "I: $in, O: $out, E: $err\n";

    $self->log_activity($user_name, $ticket, \@cmd, $out, $err, $status);

    return ($out, $err);
}
sub delete_user_rb {
    my ($self, $user_name, $ticket) = @_;

    my ($in, $out, $err);

    return ('', 'Ticket# is missing') unless ($ticket);

    my $status = 'PASS';
    #my @cmd = ('bin/f5ldap');
    my @cmd = ('/usr/bin/perl', 'bin/delete_rb.pl', $user_name);
    print "C: @cmd\n";
    eval {
        run \@cmd, \$in, \$out, \$err, timeout( 20 ) or die "cat: $?"
    };
    if ($@) {
        print "Error: $@\n";
        $status = 'FAIL'; 
    }

    print "I: $in, O: $out, E: $err\n";

    $self->log_activity($user_name, $ticket, \@cmd, $out, $err, $status);

    return ($out, $err);
}
sub p4_audit {
    my ($self, $date) = @_;

    my ($in, $out, $err);
    #my @cmd = ('bash', '-x', 'bin/f5ldap');
    my @cmd = ('/bin/bash', 'bin/audit_p4_users.sh', $date);
    print "C: @cmd\n";
    eval {
        run \@cmd, \$in, \$out, \$err, timeout( 30 ) or die "cat: $?"
    };
    if ($@) {
        print "Error: $@\n";
    }

    print "I: $in, O: $out, E: $err\n";
    return ($out, $err);
}
sub p4_licence_count {
    my ($self) = @_;

    my ($in, $out, $err);
    #my @cmd = ('bash', '-x', 'bin/f5ldap');
    my @cmd = ('/cmscripts/p4license_usage');
    print "C: @cmd\n";
    eval {
        run \@cmd, \$in, \$out, \$err, timeout( 20 ) or die "cat: $?"
    };
    if ($@) {
        print "Error: $@\n";
    }

    print "I: $in, O: $out, E: $err\n";

    return ($out, $err);
}

sub get_activity {
    my($self, $user) = @_;

    my $dbh = connect_db();
    my $sth = $dbh->prepare('select admin_user_name, user_name, ticket, activity_type, status, output, created from activity_log where user_name = ?') or die "Could not prepare: $!";
    $sth->execute($user) or die "Could not bind_param: $!";
    my $rows = $sth->fetchall_arrayref();

    my $out;
    foreach my $row (@$rows) {
        $out .= "@$row \n";
    }

    print "OUT: $out\n";

    return $rows;
}
sub check_activity {
    my($self, $user) = @_;

    my $dbh = connect_db();
    my $sth = $dbh->prepare('select user_name, activity_type, status from activity_log where user_name = ? and status = ?') or die "Could not prepare: $!";
    $sth->execute($user, 'PASS') or die "Could not bind_param: $!";
    my $rows = $sth->fetchall_arrayref();

    my ($not_ok, $out) = ('', '');
    my $req = {
        git => 0,
        bugz => 0,
        rb => 0,
    };
    foreach my $row (@$rows) {
        $out .= "@$row \n";
        $req->{$row->[1]} = 1 if($row->[1]);
    }
    print "Req: " . Dumper ($req) . "\n";

    my @pending = grep { $req->{$_} == 0 } keys %$req;

    $out = @pending 
              ? "<p>The following activities are pending: " . join(', ', @pending) . ". Please select force delete box if this OK and you want to go ahead with the delete.</p>"
              : '';

    print "Pending: @pending\n";
    return @pending;
}
sub log_activity {
    my($self, $user, $ticket, $cmd, $output, $error, $status) = @_;

    my $caller = (caller 1)[3];
    my $act_type = $1 if ($caller =~ m/delete_user_(.*)$/);

    my $admin_user = $self->{'cm_user'};
    chomp $admin_user;

    $cmd = join(' ', @$cmd);

    my $dbh = connect_db();
    my $sth = $dbh->prepare('
	insert into activity_log (ADMIN_USER_NAME, USER_NAME, TICKET, ACTIVITY_TYPE, CMD, STATUS, OUTPUT, ERROR)
        values (?, ?, ?, ?, ?, ?, ?, ?)
    ') or die "Could not prepare: $!";
    $sth->execute($admin_user, $user, $ticket, $act_type, $cmd, $status, $output, $error) or die "Could not execute: $!";
}
sub connect_db {
    my ( $self ) = shift;
    my $dbfile = config->{sql_db_file};
    my $dbh = DBI->connect( "dbi:SQLite:dbname=db/cm_admin.db", "", "", { RaiseError => 1 } );
    return $dbh;
}

1;
