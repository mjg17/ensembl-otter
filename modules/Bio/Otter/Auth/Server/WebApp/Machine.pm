package Bio::Otter::Auth::Server::WebApp::Machine;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
use Sub::Quote 'quote_sub';

extends 'Web::Machine';

has config         => ( is => 'ro' );
has request_params => ( is => 'ro', default => quote_sub q{ {} } );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

sub create_resource {
    my ($self, $request) = @_;
    return $self->{'resource'}->new(
        request  => $request,
        response => $request->new_response,
        config   => $self->config,
        %{ $self->request_params },
        );
}

1;
