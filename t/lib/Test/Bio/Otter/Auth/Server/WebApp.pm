package Test::Bio::Otter::Auth::Server::WebApp;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server';

use Plack::Test;
use Plack::Util;

use Test::Otter;
use Test::Perl::Critic;

use Bio::Otter::Git;

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
    };

    return;
}

1;
