package Bio::Otter::Auth::Server::OIDCProvider;

use strict;
use warnings;

use Bio::Otter::Auth::Server::WebUtils qw( web_machine );

# Strictly speaking we shouldn't need to do this, but CLASS->isa() is unreliable after
# use_package_optimistically() in Web::Machine otherwise.
#
use Bio::Otter::Auth::Server::OIDCProvider::Authenticate;

sub authenticate_handler {
    my ($pkg, $params) = @_;
    return web_machine('Bio::Otter::Auth::Server::OIDCProvider::Authenticate', [ %$params ] ); # (YUK hashref -> arrayref)
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
