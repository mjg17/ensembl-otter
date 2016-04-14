package Bio::Otter::Auth::Server::RelyingParty::Chooser;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::WebApp::Resource';

has callback_uri => ( is => 'rw' );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use HTML::Tags;

sub malformed_request {
    my ($self) = @_;

    unless ($self->request->session->{exists}) {
        $self->wm_warn('No session');
        return 1;
    }

    my $conflict = $self->grab_session_request_param('rp', 'callback_uri');
    return 1 if $conflict;

    my $cb = $self->callback_uri;
    unless ($cb) {
        $self->wm_warn('callback_uri not supplied');
        return 1;
    }

    # Stash the callback
    $self->request->session->{rp}->{callback_uri} = $cb;

    return;
}

sub content_types_provided { return [{'text/html' => 'to_html'}] }

sub to_html {
    my ($self) = @_;

    my $provider_config = $self->config->{ext_op};
    my $base = $provider_config->{ext_uri_base};
    my @providers;
    foreach my $key (sort keys %$provider_config) {
        my $provider = $provider_config->{$key};
        next unless ref $provider;
        push @providers,
        <li>,
          <a href="$base/$key">, $provider->{title}, </a>,
        </li>;
    }

    return [ HTML::Tags::to_html_string(   ## no critic(Subroutines::ProhibitCallsToUnexportedSubs)
        <html>,
          "Log in using:",
          <ul>,
            @providers,
          </ul>,
        </html>,
             ) ];
}

1;
