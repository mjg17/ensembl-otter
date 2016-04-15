package Test::Bio::Otter::Auth::Server::OIDCProvider::DataHandler;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server';

use Plack::Request;

use Bio::Otter::Auth::Server::WebApp::Resource;
use Bio::Otter::Auth::Server::DB::Handle;
use Bio::Otter::Auth::Server::DB::AuthInfoAdaptor;

sub our_args {
    my $req = Plack::Request->new({
        REQUEST_METHOD => q{GET},
        QUERY_STRING   => q{client_id=sample_client_id&nonce=random_nonce_str},
                                  });
    return [
        wm_resource => Bio::Otter::Auth::Server::WebApp::Resource->new(
            config => {
                # FIXME: dup with t/etc/server-config/server.yaml*
                ott_srv_op => {
                    id_token => {
                      iss => 'NOT_SET/auth',
                      expires_in => 604800,
                    },
                },
            },
            request  => $req,
            response => $req->new_response,
        ),
        dbh => Bio::Otter::Auth::Server::DB::Handle->dbh,
    ];
}

sub build_attributes { return; } # none

sub create_id_token : Tests {
    my ($test) = @_;

    my $dh = $test->our_object;
    $dh->validate_client_by_id(q{sample_client_id});
    my $id_token = $dh->create_id_token();

    isa_ok( $id_token, q{OIDC::Lite::Model::IDToken});
    is( $id_token->header->{typ}, q{JOSE}, q{id_token : header : typ} );
    is( $id_token->header->{alg}, q{RS256}, q{id_token : header : alg} );
    is( $id_token->header->{kid}, 1, q{id_token : header : kid} );
    is( $id_token->payload->{iss}, 'NOT_SET/auth', q{id_token : payload : iss} );
    is( $id_token->payload->{aud}, q{sample_client_id}, q{id_token : payload : aud} );
    is( $id_token->payload->{iat}, time(), q{id_token : payload : iat} );
    is( $id_token->payload->{exp}, time() + 604800, q{id_token : payload : exp} );
    is( $id_token->payload->{sub}, 1, q{id_token : payload : sub} );
    is( $id_token->payload->{nonce}, q{random_nonce_str}, q{id_token : payload : nonce} );

    return;
};

sub auth_info : Tests {
    my ($test) = @_;

    my $dh = $test->our_object;
    ok( not($dh->create_or_update_auth_info), 'no args');

    my %args = (
        client_id   => q{sample_client_id},
        user_id     => 1,
        scope       => q{openid},
        id_token    => q{id_token_string},
    );
    $dh->request->parameters->remove('redirect_uri');
    ok( not($dh->create_or_update_auth_info(%args)), 'redirect_uri is undef');

    $dh->request->parameters->set('redirect_uri' => 'http://localhost:5000/sample/callback');
    my $info = $dh->create_or_update_auth_info(%args);
    ok(     $info, 'args and redirect_uri are valid' );
    isa_ok( $info, 'Bio::Otter::Auth::Server::OIDCProvider::AuthInfo');
    ok(     $info->id,   'auth_info->id' );
    ok(     $info->code, 'auth_info->code' );
    is(     $info->code_expires_at, time() + 5*60, 'auth_info->code_expired_on' );

    my $ai_ad = Bio::Otter::Auth::Server::DB::AuthInfoAdaptor->new(Bio::Otter::Auth::Server::DB::Handle->dbh);
    my $saved_info = $ai_ad->fetch_by_id($info->id);
    is_deeply( $saved_info, $info, 'found auth_info is valid');

    $saved_info = $dh->get_auth_info_by_id($info->id);
    is_deeply( $saved_info, $info, 'get_auth_info_by_id is valid');

    $saved_info = $dh->get_auth_info_by_code($info->code);
    is_deeply( $saved_info, $info, 'get_auth_info_by_code is valid');

    $info->set_refresh_token();
    $ai_ad->store_or_update($info);
    $saved_info = $dh->get_auth_info_by_refresh_token($info->refresh_token);
    is_deeply( $saved_info, $info, 'get_auth_info_by_refresh_token is valid');

    return;
}

sub access_token : Tests {
    my ($test) = @_;

    my $dh = $test->our_object;
    ok( not($dh->create_or_update_access_token), 'no args');

    my %args = (
        client_id   => q{sample_client_id},
        user_id     => 1,
        scope       => q{openid},
        id_token    => q{id_token_string},
    );
    $dh->request->parameters->remove('grant_type');
    $dh->request->parameters->remove('redirect_uri');
    $dh->request->parameters->set('redirect_uri' => 'http://localhost:5000/sample/callback');
    ok( not($dh->create_or_update_access_token(%args)), 'auth_info is undef');

    my $info = $dh->create_or_update_auth_info(%args);
    my $token = $dh->create_or_update_access_token(auth_info => $info);
    ok( $token, 'auth_info is valid' );
    isa_ok( $token, 'Bio::Otter::Auth::Server::OIDCProvider::AccessToken');
    is( $token->auth_id, $info->id, 'AccessToken->auth_id eq AuthInfo->id' );

    my $ai_ad = Bio::Otter::Auth::Server::DB::AuthInfoAdaptor->new(Bio::Otter::Auth::Server::DB::Handle->dbh);
    my $saved_info = $ai_ad->fetch_by_id($info->id);
    ok( $saved_info, 'auth_info is saved');

    $dh->request->parameters->set('grant_type' => 'authorization_code');
    $info = $dh->create_or_update_auth_info(%args);
    $token = $dh->create_or_update_access_token(auth_info => $info);
    isa_ok( $token, 'Bio::Otter::Auth::Server::OIDCProvider::AccessToken');
    is( $token->auth_id, $info->id, 'AccessToken->auth_id eq AuthInfo->id' );

    $saved_info = $ai_ad->fetch_by_id($info->id);
    ok( not($saved_info->code), 'auth_info->code is deleted');
    is( $saved_info->code_expires_at, 0, 'auth_info->code_expired_on is deleted');

    my $decoded_token = $dh->get_access_token($token->token);
    is_deeply($decoded_token, $token, 'get_access_token');

    return;
}

1;

