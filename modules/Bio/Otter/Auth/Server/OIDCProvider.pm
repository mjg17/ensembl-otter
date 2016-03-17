package Bio::Otter::Auth::Server::OIDCProvider;

use strict;
use warnings;

use Data::Dumper;               # TMP

sub authenticate_handler {
    my ($pkg, $params) = @_;
    return sub { [ 200, [ 'Content-type' => 'text/plain' ], [ 'OP_authenticate:', Dumper $params ] ] };
}

use OIDC::Lite::Server::Endpoint::Token;
my $token_endpoint = OIDC::Lite::Server::Endpoint::Token->new(
    data_handler => 'Bio::Otter::Auth::ServerOP::DataHandler',
);
$token_endpoint->support_grant_types(qw(authorization_code));

sub token_handler {
    return $token_endpoint->psgi_app;
}

1;
