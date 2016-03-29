package Test::Bio::Otter::Auth::Server::OIDCProvider::Authenticate;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server';

# This smells a bit:
#
use HTTP::Request;
use HTTP::Message::PSGI;        # inject to_psgi()
use Plack::Request;
use Plack::Response;

sub build_attributes { return; } # none

sub our_args {
    my $req = HTTP::Request->new(GET => '/');
    my $env = $req->to_psgi;
    return [
        request  => Plack::Request->new($env),
        response => Plack::Response->new(),
        ];
}

1;

