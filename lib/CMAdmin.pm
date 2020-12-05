package CMAdmin;
use Dancer2;
use Api::View;
use AppUtils;
use Data::Dumper;

our $VERSION = '0.1';
our $temp;
our %params;

my %titles = (
    'delete_user_bugz' => "Disable Bugzilla User",
    'delete_user_git' => "Disable Gitlab User",
    'delete_user_rb' => "Disable Review Board User",
    'delete_user_p4_audit' => "Delete- Dir & CL if Any",
    'delete_user_p4_remove' => "Delete Persons - p4 Remove",
    'mgr_view' => "Manager View",
    'f5ldap_check' => "F5 Ldap Check",
    'cleanup_build' => "Work Space / Build Cleanup",
    'p4_audit' => "P4 last Login Audit",
    'p4_licence Count' => "P4 Licence Count",
);

set logger => "File::RotateLogs";

hook before => sub {

    if ( request->path !~ m/(login|login_user|logout)/ ) {

        if ( !session( 'user_name' ) || defined session( 'expiry_time' ) && session( 'expiry_time' ) - time < 1 ) {

            # Pass the original path requested along to the handler:
            $temp->{path} = request->path;
            debug "Requested path $temp->{path} redirecting to login";
            forward '/login';
        }
    }
};

hook before_template_render => sub {
    my $tokens = shift;
    $tokens->{sess_user} = session( 'user_name' );
    #print "Before_template_render hook", Dumper $tokens, "\n";
};


any '/login' => sub {
    set layout   => undef;
    send_as html => template 'login';
};

post '/login_user' => sub {
    my $user_value = body_parameters->get( 'user_name' );
    my $pass_value = body_parameters->get( 'password' );

    my ( $user, $valid ) = AppUtils->new->validate_credential( $user_value, $pass_value );

    if ( !$user ) {
        debug "Failed login for unrecognised user $user_value";
        status '403';
	return encode_json({ success => 0 });

        # redirect '/login?failed=1';
    } else {
        set layout => "main";
        if ( $valid ) {
            session user_name => $user_value;
            my $exp = time + config->{session_expiry_sec};
            session expiry_time => $exp;

            info "'$user_value' logged in Successfully expiry set to $exp";
            my $path = delete $temp->{path};

            # my $path_info = delete $temp->{path_info};
            info "redirecting to $path or '/'";
            return encode_json ({ success => 1, redirect => $path || '/' });

            # redirect $path || $path_info || '/';
        } else {
            debug "Login failed - password incorrect for  $user_value";
            status '403';
            return encode_json({ success => 0 });
        }
    }
};

any [ 'get', 'post' ] => '/' => sub {
    #DEFAULT
    forward '/mgr_view';

};

any [ 'get', 'post' ] => '/logout' => sub {
    app->destroy_session;
    redirect '/';
};

get '/add_user' => sub {
    set layout => "main";
    send_as
      html => template 'add_user.tt',
      { is_get => 1, result_set => Api::View->new->get_add_user_form() };
};

post '/add_user' => sub {
    my ( $result, $error ) = Api::View->new->add_user( \%{ params( 'body' ) } );
    debug "Add user result $result error : $error paramas" . Dumper( \%{ params( 'body' ) } );

    return encode_json({ result => $result, success => $error ? 0 : 1 });

};

get '/rb_add_user' => sub {
    set layout => "main";
    send_as html => template 'rb_add_user.tt',
      { is_get => 1 };
};

post '/review_group/add_user' => sub {
    header('Content-Type' => 'application/json');
    my $params = decode_json(request->body);

    my ($result, $error) = Api::View->new->review_grp_add_user($params);
    debug "rb add user result $result->{stat}, error: $error for params:" . Dumper($params);

    if( $error ) {
        return encode_json( {stat => $result->{stat}, msg => $result->{err}{msg}, error => $error } );
    } else {
        return encode_json( {stat => $result->{stat}, msg => "User $params->{username} added to review group $params->{group_name}", error => $error } );
    }
};

get '/rb_remove_user' => sub {
    set layout => "main";
    send_as html => template 'rb_remove_user.tt',
      { is_get => 1 };
};

post '/review_group/remove_user' => sub {
    header('Content-Type' => 'application/json');
    my $params = decode_json(request->body);
    my ($result, $error) = Api::View->new->review_grp_remove_user($params);
    debug "rb remove user result" . Dumper($result) . "error: $error for params:" . Dumper($params);

    if( $error ) {
        return encode_json( {stat => $result->{stat}, msg => $result->{err}{msg}, error => $error } );
    } else {
        return encode_json( {stat => $result, msg => "User $params->{username} removed from review group $params->{group_name}", error => $error } );
    }
};


my @valid_params = qw(username ticket delete_type buildname date);
any [ 'get', 'post' ] => '/*' => sub {
    set layout => "main";

    my $user_value = body_parameters->get( 'username' );
    my $ticket = body_parameters->get( 'ticket' );
    my $delete_type = body_parameters->get( 'delete_type' );
    my $force_delete = body_parameters->get( 'force_delete' );
    my $remove = body_parameters->get( 'remove' );
    my $buildname = body_parameters->get( 'buildname' );
    my $date = body_parameters->get( 'date' );

    my $path = request->path;
    $path =~ s!^/!!;

    print "Path: $path\n";
    print "User: $user_value\n" if($user_value);
    info "Path: $path"; 
    info "User: $user_value" if($user_value);

    my @params;
    push @params, $user_value if($user_value);
    push @params, $ticket if($ticket);
    my $template = 'cmadmin.tt';

    if ($path eq 'delete_user_p4_audit') {
        $template = "$path.tt";
        push @params, $delete_type if($delete_type); # push if multi param form
        push @params, $force_delete if($force_delete); 
    }
    if ($path eq 'delete_user_p4_remove') {
        $template = "$path.tt";
        push @params, $remove if($remove);
        push @params, $force_delete if($force_delete); 
    }
    if ($path eq 'cleanup_build') {
        $template = "$path.tt";
        push @params, $buildname if($buildname);
    }
    if ($path eq 'p4_audit') {
        $template = "$path.tt";
        @params = $date if ($date); # assign if single param form
    }
    if ($path eq 'mgr_view') {
        $template = "$path.tt";
    }
    if ($path eq 'f5ldap_check') {
        $template = "$path.tt";
    }
    if ($path eq 'p4_licence_count') {
        $template = "$path.tt";
        @params = 'dummy'; # no form fields
    }

    print "Template: $template, Params: " . join(':', @params) . "\n";

    my ($result, $error, $info, $pending);
    ($result, $error, $info, $pending) = Api::View->new('cm_user' => session('user_name'))->$path(@params) if($#params != -1);
    print "Result: $result\n" if($result);
    print "Error: $error\n" if($error);
    print "Info: ", Dumper($info), "\n" if($info);
    print "Pending: ", Dumper($pending), "\n" if($pending);

    send_as
        html => template $template,
        { 
            h1title => $titles{$path},
            path => "/$path",

            result => $result,
            error => $error,
            info => $info,
            pending => $pending,

            username => $user_value,
            ticket => $ticket,

            buildname => $buildname,
            date => $date,
        };
};

true;
