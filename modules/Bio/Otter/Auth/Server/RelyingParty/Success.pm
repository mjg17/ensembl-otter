package Bio::Otter::Auth::Server::RelyingParty::Success;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::WebApp::Resource';

has 'auth_info' => ( is => 'rw' );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use HTML::Tags;

sub malformed_request {
    my ($self) = @_;
    return if $self->auth_info($self->request->session->{auth_info});

    $self->wm_warn('No auth_info in session');
    return 1;
}

sub content_types_provided { return [{'text/html' => 'to_html'}] }

sub to_html {
    my ($self) = @_;

    my @auth_info;
    foreach my $key (sort keys %{$self->auth_info}) {
        my $value = $self->auth_info->{$key};
        $value = '[hidden]' if $key eq 'access_token';

        # FIXME: http escapes
        push @auth_info,
        <dt>, $key, </dt>,
        <dd>, $value, </dd>,
    }

    return [ HTML::Tags::to_html_string(   ## no critic(Subroutines::ProhibitCallsToUnexportedSubs)
        <html>,
          "Log in succeded:",
          <dl>,
            @auth_info,
          </dl>,
        </html>,
             ) ];
}

1;
