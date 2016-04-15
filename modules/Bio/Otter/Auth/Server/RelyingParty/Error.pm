package Bio::Otter::Auth::Server::RelyingParty::Error;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::WebApp::Resource';

has 'error_info' => ( is => 'rw' );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use HTML::Tags;

sub malformed_request {
    my ($self) = @_;
    return if $self->error_info($self->request->session->{error_info});

    # $self->wm_warn('No error_info in session');
    # return 1;

    $self->error_info([]);
    return;
}

sub content_types_provided { return [{'text/html' => 'to_html'}] }

sub to_html {
    my ($self) = @_;

    my @error_info;
    foreach my $key (sort keys %{$self->error_info}) {
        my $value = $self->error_info->{$key};

        # FIXME: http escapes
        push @error_info,
        <dt>, $key, </dt>,
        <dd>, $value, </dd>,
    }

    return [ HTML::Tags::to_html_string(   ## no critic(Subroutines::ProhibitCallsToUnexportedSubs)
        <html>,
          "Something went wrong:",
          <dl>,
            @error_info,
          </dl>,
        </html>,
             ) ];
}

1;
