package Test::Bio::Otter::Auth::Server::OIDCProvider::AccessToken;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server',
    attributes => [ qw( time_stamp ) ];

use Test::MockTime qw( set_fixed_time );

use Bio::Otter::Auth::Server::OIDCProvider::AuthInfo;

sub fix_time : Test(startup) {
    my ($test) = @_;
    my $ts = time;
    set_fixed_time($ts);
    $test->time_stamp($ts);
    return;
}

sub our_args {
    return [ {
        auth_id => 'spqr1@sanger.ac.uk',
        token   => 'sample-token',
             } ];
}

sub build_attributes { return; }

sub create : Tests {
    my ($test) = @_;

    ok( not($test->class->create), 'no auth_info');

    my $info = $test->_build_auth_info;
    my $token = $test->class->create($info);
    isa_ok($token, $test->class);
    is( $token->auth_id,       100, 'AccessToken->auth_id' );
    is( $token->expires_in,  86400, 'AccessToken->expires_in' );
    is( $token->created_on, time(), 'AccessToken->created_on' );

    return;
}

sub validate : Tests {
    my ($test) = @_;

    my $info = $test->_build_auth_info;
    my $token = $test->class->create($info);

    my $decoded_token = $test->class->validate($token->token);
    is_deeply($decoded_token, $token, 'decoded AccessToken is valid');

    my $ts = $test->time_stamp;
    set_fixed_time($ts - 86400 - 1);
    $token = $test->class->create($info);
    set_fixed_time($ts);
    $decoded_token = $test->class->validate($token->token);
    ok( not($decoded_token), 'AccessToken is expired');

    return;
}

sub _build_auth_info {
    my $args = {
        user_id   => 1,
        client_id => q{sample_client_id},
        scope     => q{openid},
    };
    my $info = Bio::Otter::Auth::Server::OIDCProvider::AuthInfo->create(%$args);
    $info->id(100);
    return $info;
}

1;
