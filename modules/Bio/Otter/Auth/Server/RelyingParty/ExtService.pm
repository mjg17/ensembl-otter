package Bio::Otter::Auth::Server::RelyingParty::ExtService;

# Base class for endpoints requiring an ext_service component

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::WebApp::Resource';

has ext_service     => ( is => 'ro' );

has _service_config => ( is => 'ro', builder => 1, lazy => 1 );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use OAuth::Lite2::Client::WebServer;

sub _build__service_config {
    my ($self) = @_;
    if (my $ext_service = $self->ext_service) {
        my $service_config = $self->config->{ext_op}->{$ext_service};
        return $service_config;
    }
    return;
}

sub malformed_request {
    my ($self) = @_;
    $self->_wm_warn('/:service not specified'), return 1 unless $self->ext_service;

    unless ($self->_service_config) {
        my $es = $self->ext_service;
        $self->_wm_warn("no config for service '$es'");
        return 1;
    }

    return;
}

# Should this be here or elsewhere?
sub previously_existed { return 1; }


# Maybe we should be using different roles? This isn't really about extservice.
sub web_client {
    my ($self, $config) = @_;

    return OAuth::Lite2::Client::WebServer->new(
        id               => $config->{'client_id'},
        secret           => $config->{'client_secret'},
        authorize_uri    => $config->{'authorization_endpoint'},
        access_token_uri => $config->{'token_endpoint'},
        );
}

1;
