package Bio::Otter::Auth::Server::RelyingParty::Callback;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::RelyingParty::ExtService';

has state => ( is => 'ro' );
has code  => ( is => 'ro' );

has session_state => ( is => 'rw' );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

sub content_types_provided { return [{'*/*' => sub { return 'Not expecting to render!'} }] }

around malformed_request => sub { ##  no critic(Subroutines::ProhibitCallsToUndeclaredSubs)
    my ($orig, $self) = @_;

    my $ext_service_mf = $orig->($self);
    return $ext_service_mf if $ext_service_mf;

    do { $self->wm_warn('state not supplied'); return 1 } unless $self->state;
    do { $self->wm_warn('code not supplied');  return 1 } unless $self->code;

    # SEE ALSO ::Chooser
    my $session_state = $self->_get_state($self->ext_service);
    do { $self->wm_warn('no session state'); return 1 } unless $session_state;
    $self->session_state($session_state);

    return;
};

sub forbidden {
    my ($self) = @_;

    return if $self->_verify_state($self->session_state, $self->state);

    $self->wm_warn('state mismatch');
    return 1;
}

# at best we are going to redirect
sub resource_exists { return }

sub moved_temporarily {
    my ($self) = @_;
    my $config = $self->_service_config;

    my $uri = $self->config->{ott_srv_rp}->{error_uri};

    my ($token, $response) = $self->_get_access_token($self->code);
    return $uri unless $token;

    my $auth_info = $self->decode_token_response($token, $response);
    return $uri unless $auth_info;

    # success!!
    $self->request->session->{'auth_info'} = $auth_info;
    $self->request->session_options->{'change_id'} = 1;

    $uri = $self->config->{ott_srv_rp}->{success_uri};
    return $uri;
}

# FIXME: state handling stuff should be somewhere common
sub _get_state {
    my ($self, $service) = @_;
    my $session = $self->request->session;
    return $session->{'state_' . $service};
}

sub _verify_state {
    my ($self, $session_state, $callback_state) = @_;

    return unless $session_state;
    return unless $callback_state;

    unless ($session_state eq $callback_state) {
        $self->wm_warn(sprintf "session state '%s' != callback state '%s'", $session_state, $callback_state);
        return;
    }

    return 1; # okay
}

sub _get_access_token {
    my ($self, $code) = @_;

    my $config = $self->_service_config;

    my $client = $self->web_client($self->_service_config);

    my $token = $client->get_access_token(
        code         => $code,
        redirect_uri => $config->{redirect_uri},
        );
    my $response = $client->last_response;

    unless ($token) {
        $self->wm_warn(sprintf "failed to get access token, '%s'", $response->content);
    }

    return ($token, $response);
}

1;
