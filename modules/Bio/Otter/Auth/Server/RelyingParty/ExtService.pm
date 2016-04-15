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

use Role::Tiny qw();
use Try::Tiny  qw( try catch );

# use OAuth::Lite2::Client::WebServer;
use OIDC::Lite::Client::WebServer;

# TEMP workaround for Apache2 / Otter::Paths only run once ??
#
use Bio::Otter::Auth::Server::RelyingParty::Profile::Google;
use Bio::Otter::Auth::Server::RelyingParty::Profile::Orcid;

sub _build__service_config {    ## no critic(Subroutines::ProhibitUnusedPrivateSubroutines)
    my ($self) = @_;
    if (my $ext_service = $self->ext_service) {
        my $service_config = $self->config->{ext_op}->{$ext_service};
        return $service_config;
    }
    return;
}

# This is somewhat appropriate, and also a handy early stage in the FSM for setup.
#
sub malformed_request {
    my ($self) = @_;

    my $es = $self->ext_service;
    unless ($es) {
        $self->wm_warn('/:service not specified');
        return 1;
    }

    unless ($self->_service_config) {
        $self->wm_warn("no config for service '$es'");
        return 1;
    }

    my $err = $self->_load_profile($es);
    if ($err) {
        $self->wm_warn("failed to load profile for service '$es': '$err'");
        return 1;
    }

    return;
}

sub _load_profile {
    my ($self, $ext_service) = @_;

    my $profile = 'Bio::Otter::Auth::Server::RelyingParty::Profile::' . ucfirst $ext_service;

    my $err;
    try {
        Role::Tiny->apply_roles_to_object( $self, $profile );
    }
    catch {
        $err = $_ || '(no details)';
    };
    return $err;
}

# Should this be here or elsewhere?
sub previously_existed { return 1; }


# Maybe we should be using different roles? This isn't really about extservice.
sub web_client {
    my ($self, $config) = @_;

    # Does Orcid need OAuth::Lite2::Client::WebServer ??
    return OIDC::Lite::Client::WebServer->new(
        id               => $config->{'client_id'},
        secret           => $config->{'client_secret'},
        authorize_uri    => $config->{'authorization_endpoint'},
        access_token_uri => $config->{'token_endpoint'},
        );
}

1;
