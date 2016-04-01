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
    return not $self->ext_service;
}

sub previously_existed {
    my ($self) = @_;
    unless ($self->_service_config) {
        return;                 # => 404 not found
    }
    return 1;
}

1;
