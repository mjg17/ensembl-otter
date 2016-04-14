package Bio::Otter::Auth::Server::WebApp::Resource;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Web::Machine::Resource';

has config => ( is => 'ro' );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

sub set_session_request_param {
    my ($self, $domain, $key, $value) = @_;
    return $self->request->session->{$domain}->{'_request'}->{$key} = $value;
}

sub grab_session_request_param {
    my ($self, $domain, $key) = @_;

    my $session_value = delete $self->request->session->{$domain}->{'_request'}->{$key};
    return unless $session_value;

    if (my $query_value = $self->$key()) {
        $self->wm_warn("already have value for '$key' - from URI?");
        return 1;
    }

    $self->$key($session_value);
    return;
}

sub wm_warn {
    my ($self, $msg) = @_;
    warn sprintf "-- %s: %s\n", ref($self), $msg;
    return;
}

1;
