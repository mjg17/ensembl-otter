package Bio::Otter::Auth::Server::OIDCProvider;

use strict;
use warnings;

use OIDC::Lite::Server::Endpoint::Token;

my $token_endpoint = OIDC::Lite::Server::Endpoint::Token->new(
    data_handler => 'Bio::Otter::Auth::ServerOP::DataHandler',
);
$token_endpoint->support_grant_types(qw(authorization_code));

sub token_handler {
    return $token_endpoint->psgi_app;
}

1;
