package Bio::Otter::Auth::Server::OIDCProvider;

use strict;
use warnings;

use Web::Machine;

# FIXME: role or class
sub _make_wm {
    my ($resource, $resource_args) = @_;
    my $machine = Web::Machine->new(
        resource      => $resource,
        resource_args => $resource_args,
        );
    return $machine;
}

use Data::Dumper;            # TMP

# Strictly speaking we shouldn't need to do this, but CLASS->isa() is unreliable after
# use_package_optimistically() in Web::Machine otherwise.
#
use Bio::Otter::Auth::Server::OIDCProvider::Authenticate;

sub authenticate_handler {
    my ($pkg, $params) = @_;
    warn 'OP_authenticate', Dumper($params), "\n";
    return _make_wm('Bio::Otter::Auth::Server::OIDCProvider::Authenticate', [ %$params ] ); # (YUK hashref -> arrayref)
    # sub { [ 200, [ 'Content-type' => 'text/plain' ], [ 'OP_authenticate:', Dumper $params ] ] };
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
