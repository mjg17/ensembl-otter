package Test::Bio::Otter::Auth::Server::WebApp;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server';

use Plack::Test;
use Plack::Util;

use Test::Otter;
use Test::Perl::Critic;

sub build_attributes { return; } # none

my $auth_script;
BEGIN {
    $auth_script = Test::Otter->proj_rel('scripts/psgi/auth');
}

sub test_psgi_auth_basics : Tests {

    require_ok($auth_script);
    critic_ok( $auth_script);

    return;
}

sub test_psgi_auth_plack : Tests {

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
            is $res->headers->header('Location'), 'http://localhost/chooser';
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
            is $res->code, 404, '... external needs a service we support ...';

            $req = HTTP::Request->new(GET => 'http://localhost/external/google');
            $req->header('Cookie' => $session_cookie);
            $res = $cb->($req);
            is $res->code, 307, '... google redirect ...';
            like $res->headers->header('Location'), qr(^https://accounts.google.com/o/oauth2/auth), '... header';
        };

    return;
}

1;
