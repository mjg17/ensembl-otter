package Bio::Otter::Auth::Server::RelyingParty::Chooser;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::WebApp::Resource';

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use HTML::Tags;

sub malformed_request {
    my ($self) = @_;
    return if $self->request->session->{exists};

    $self->wm_warn('No session');
    return 1;
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
