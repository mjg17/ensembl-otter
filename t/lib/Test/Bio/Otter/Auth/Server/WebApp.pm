package Test::Bio::Otter::Auth::Server::WebApp;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server';

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

    $ENV{OTTER_MAJOR} = '102'; # TMP - what to do longer-term?

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
        };

    return;
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

1;
