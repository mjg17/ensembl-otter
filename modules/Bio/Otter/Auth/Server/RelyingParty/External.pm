package Bio::Otter::Auth::Server::RelyingParty::External;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Web::Machine::Resource';

# consider using DrinkUp pattern instead
has ext_service     => ( is => 'rw' );

has _service_config => ( is => 'rw' );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

sub init {
    my ($self, $args) = @_;
    $self->ext_service($args->{ext_service});
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
    my $service_config;    # search config
    unless ($service_config) {
        return;
    }
    return 1;
}

1;
