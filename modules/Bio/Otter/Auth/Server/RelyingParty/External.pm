package Bio::Otter::Auth::Server::RelyingParty::External;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::WebApp::Resource';

has ext_service     => ( is => 'ro' );

has _service_config => ( is => 'ro', builder => 1, lazy => 1 );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Crypt::OpenSSL::Random            qw( random_pseudo_bytes );
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
    return not $self->ext_service;
}

sub content_types_provided { return [{'*/*' => sub { return 'Not expecting to render!'} }] }

# at best we are going to redirect
sub resource_exists { return }

sub previously_existed {
    my ($self) = @_;
    unless ($self->_service_config) {
        return;                 # => 404 not found
    }
    return 1;
}

sub moved_temporarily {
    my ($self) = @_;
    my $config = $self->_service_config;

    my $state = $self->_generate_save_state($self->ext_service);
    my $uri = $self->_auth_endpoint($config, $state);

    return $uri;
}

sub _generate_save_state {
    my ($self, $service) = @_;
    my $state = $self->_generate_state($service);
    return $self->_set_state($service, $state);
}

sub _generate_state {
    my ($self, $service) = @_;
    my $rand = unpack('H*', $service . random_pseudo_bytes(32)); # OIDC::Lite::Demo::Client::Session uses existing if present
    my $version = $ENV{OTTER_MAJOR};
    return "$version:$rand";
}

sub _set_state {
    my ($self, $service, $state) = @_;
    my $session = $self->request->session;
    return $session->{'state_' . $service} = $state;
}

sub _auth_endpoint {
    my ($self, $config, $state) = @_;
    return $self->_client($config)->uri_to_redirect(
        redirect_uri => $config->{'redirect_uri'},
        scope        => $config->{'scope'},
        state        => $state,
        extra        => $config->{'auth_extra'} || {},
        );
}

sub _client {
    my ($self, $config) = @_;

    return OAuth::Lite2::Client::WebServer->new(
        id               => $config->{'client_id'},
        secret           => $config->{'client_secret'},
        authorize_uri    => $config->{'authorization_endpoint'},
        access_token_uri => $config->{'token_endpoint'},
        );
}

1;
