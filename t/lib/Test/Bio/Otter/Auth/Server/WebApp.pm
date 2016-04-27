package Test::Bio::Otter::Auth::Server::WebApp;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server';

use HTTP::Request::Common qw( POST );
use Plack::Test;
use Plack::Util;
use URI;
use URI::QueryParam;

use Test::Otter;
use Test::Perl::Critic;

sub build_attributes { return; } # none

my ($auth_script, $redirect_script);
BEGIN {
    $auth_script     = Test::Otter->proj_rel('scripts/psgi/auth');
    $redirect_script = Test::Otter->proj_rel('scripts/psgi/_version_independent/_auth_version_rewrite');
}

sub test_psgi_auth_basics : Tests {

    require_ok($auth_script);
    critic_ok( $auth_script);

    return;
}

sub test_psgi_auth_plack : Tests {
    my ($test) = @_;

    $ENV{OTTER_MAJOR} = '103'; # TMP - what to do longer-term?

    my $app = Plack::Util::load_psgi $auth_script;

    test_psgi
        app => $app,
        client => sub {
            my $cb = shift;

            my $req = HTTP::Request->new(GET => 'http://localhost/');
            my $res = $cb->($req);
            is $res->code, 404;     # not found
            note "Content: ", $res->content;

            $req = HTTP::Request->new(GET => 'http://localhost/authenticate');
            $res = $cb->($req);
            is $res->code, 307;     # redirect
            is $res->headers->header('Location'), 'NOT_SET/chooser';
            my $session_cookie = $res->headers->header('Set-Cookie');
            note("Cookie: ", $session_cookie);
            ok $session_cookie, '... has session cookie';

            $req = HTTP::Request->new(GET => 'http://localhost/chooser?callback_uri=blahblah');
            $req->header('Cookie' => $session_cookie);
            $res = $cb->($req);
            is $res->code, 400, 'URI/session conflict';

            # Reset session param
            $req = HTTP::Request->new(GET => 'http://localhost/authenticate');
            $res = $cb->($req);
            is $res->code, 307;     # redirect
            $session_cookie = $res->headers->header('Set-Cookie');
            ok $session_cookie, '... has session cookie';

            $req = HTTP::Request->new(GET => 'http://localhost/chooser');
            $req->header('Cookie' => $session_cookie);
            $res = $cb->($req);
            is $res->code, 200;
            ok $res->content, '... has content';
            note "Content: ", $res->content;

            $req = HTTP::Request->new(GET => 'http://localhost/external/xxx');
            $req->header('Cookie' => $session_cookie);
            $res = $cb->($req);
            is $res->code, 400, '... external needs a service we support ...';

            $req = HTTP::Request->new(GET => 'http://localhost/external/google');
            $req->header('Cookie' => $session_cookie);
            $res = $cb->($req);
            is $res->code, 307, '... google redirect ...';
            my $location = $res->headers->header('Location');
            like $location, qr(^https://accounts.google.com/o/oauth2/auth), '... header';
            my $state = URI->new($location)->query_param('state');
            ok $state, '... state';

            $req = HTTP::Request->new(GET => 'http://localhost/callback/xxx?state=babing&code=boing');
            $req->header('Cookie' => $session_cookie);
            $res = $cb->($req);
            is $res->code, 400, '... callback needs a service we support ...';

            $req = HTTP::Request->new(GET => 'http://localhost/callback/google');
            $req->header('Cookie' => $session_cookie);
            $res = $cb->($req);
            is $res->code, 400, '... callback needs state & code ...';

            $req = HTTP::Request->new(GET => 'http://localhost/callback/google?state=babing');
            $req->header('Cookie' => $session_cookie);
            $res = $cb->($req);
            is $res->code, 400, '... callback needs code too ...';

            $req = HTTP::Request->new(GET => 'http://localhost/callback/google?state=babing&code=doing');
            $req->header('Cookie' => $session_cookie);
            $res = $cb->($req);
            is $res->code, 403, '... callback state mismatch ...';

            $req = HTTP::Request->new(GET => "http://localhost/callback/google?state=${state}&code=doing");
            $req->header('Cookie' => $session_cookie);
            $res = $cb->($req);
            is $res->code, 307, '... callback redirects ...';

            $req = HTTP::Request->new(GET => "http://localhost/rp/success");
            $res = $cb->($req);
            is $res->code, 400, '... rp/success needs auth_info session ...';

            $req = HTTP::Request->new(GET => "http://localhost/op/authorise");
            $res = $cb->($req);
            is $res->code, 400, '... op/authorise needs auth_info session ...';

            $req = HTTP::Request->new(GET => "http://localhost/op/authorise");
            my $cookie_spec = $test->_create_session_and_cookie_spec();
            $req->header('Cookie' => $cookie_spec);
            $res = $cb->($req);
            is $res->code, 307, '... op/authorise redirects to error ...';
            $location = $res->headers->header('Location');
            like $location, qr(^NOT_SET/op/error), '... error';

            $req = HTTP::Request->new(GET => "http://localhost/op/authorise");
            $cookie_spec = $test->_create_session_and_cookie_spec(
                'read-check@google.com', '/REDIRECT_from_session', 'xyzzy');
            $req->header('Cookie' => $cookie_spec);
            $res = $cb->($req);
            is $res->code, 307, '... op/authorise does something? ...';
            $location = $res->headers->header('Location');
            like $location, qr(^/REDIRECT_from_session), '... success!!';
            my $uri = URI->new($location);
            my $code = $uri->query_param('code');
            ok $code, '... have code';
            is $uri->query_param('state'), 'xyzzy', '... state';

            $req = POST "http://localhost/token", [ 'grant_type' => 'authorization_code' ];
            $res = $cb->($req);
            is $res->code, 400, '... POST token - bad request ...';

            $req = POST "http://localhost/token", [
                'grant_type'    => 'authorization_code',
                'client_id'     => 'test-client-id',
                'client_secret' => 'test-client-secret',
                'code'          => 'xyzzyzzy',
                'redirect_uri'  => '/REDIRECT_from_session',
            ];
            $res = $cb->($req);
            is $res->code, 401, '... POST token - bad code ...';

            $req = POST "http://localhost/token", [
                'grant_type'    => 'authorization_code',
                'client_id'     => 'test-client-id',
                'client_secret' => 'test-client-secret',
                'code'          => $code,
                'redirect_uri'  => '/REDIRECT_from_session',
            ];
            $res = $cb->($req);
            is $res->code, 200, '... POST token - got there! ...';
            note "Content: ", $res->content;
        };

    return;
}

sub _create_session_and_cookie_spec {
    my ($test, $identifier, $redirect, $state) = @_;
    $identifier //= 'mickey@mouse.disney';
    $redirect   //= '/SHOULD_NOT_BE_USED';

    # otter_TEST_sid=1c342861342aaa78060ba040dac28f7219f23d39; path=/
    my $sid =       'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef';

    $test->_create_session($sid, {
        'op' => {
            '_request' => {
                'auth_info' => {
                    'provider'   => 'Google',
                    'identifier' => $identifier,
                }
            },
            'auth_request' => {
                response_type => 'code',
                redirect_uri  => $redirect,
                scope         => 'openid email',
                client_id     => 'test-client-id',
                $state ? ('state' => $state) : (),
            },
        }
                          });
    my $cookie_spec = "otter_TEST_sid=${sid}; path=/";
    return $cookie_spec;
}

sub test_psgi_redirect_basics : Tests {

    require_ok($redirect_script);
    critic_ok( $redirect_script);

    return;
}

sub test_psgi_redirect_plack : Tests {

    my $app = Plack::Util::load_psgi $redirect_script;

    test_psgi
        app => $app,
        client => sub {
            my $cb = shift;

            my $req = HTTP::Request->new(GET => 'https://localhost/auth/callback?state=102:deadbeef');
            my $res = $cb->($req);
            is $res->code, 307, 'redirect ...';
            my $loc = $res->headers->header('Location');
            like $loc, qr(^https://localhost/102/auth), '... header';
            note "Location: $loc";

            $req = HTTP::Request->new(GET => 'https://localhost/auth/callback');
            $res = $cb->($req);
            is $res->code, 400, 'fail no state ...';

            $req = HTTP::Request->new(GET => 'https://localhost/auth/callback?state=deadbeef');
            $res = $cb->($req);
            is $res->code, 400, 'fail malformed state ...';

            $req = HTTP::Request->new(GET => 'https://localhost/auth/callback?state=strange:deadbeef');
            $res = $cb->($req);
            is $res->code, 400, 'fail illegal version ...';

            $req = HTTP::Request->new(GET => 'https://localhost/not_auth/callback?state=strange:deadbeef');
            $res = $cb->($req);
            is $res->code, 400, 'fail bad uri ...';
    };

    return;
}

sub _create_session {
    my ($test, $id, $session) = @_;

    my $config = Bio::Otter::Server::Config->Server;
    my $dbh    = Bio::Otter::Auth::Server::DB::Handle->dbh;
    my $chi    = CHI->new(%{$config->{ott_srv}->{CHI}}, dbh => $dbh);

    my $store = Plack::Session::Store::Cache->new(cache => $chi);
    $store->store($id, $session);

    return;
}

1;
