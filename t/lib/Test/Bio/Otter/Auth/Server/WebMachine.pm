package Test::Bio::Otter::Auth::Server::WebMachine;

use Test::Class::Most
    parent      => 'Test::Bio::Otter::Auth::Server',
    is_abstract => 1;

use HTTP::Request;
use HTTP::Message::PSGI;        # inject to_psgi()
use Plack::Request;
use Plack::Response;

sub our_args {
    my $req = HTTP::Request->new(GET => '/');
    my $env = $req->to_psgi;
    return [
        request  => Plack::Request->new($env),
        response => Plack::Response->new(),
        ];
}

1;
