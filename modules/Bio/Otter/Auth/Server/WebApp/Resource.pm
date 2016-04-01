package Bio::Otter::Auth::Server::WebApp::Resource;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Web::Machine::Resource';

has config => ( is => 'ro' );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

sub _wm_warn {
    my ($self, $msg) = @_;
    warn sprintf "-- %s: %s\n", ref($self), $msg;
    return;
}

sub _wm_die {                   # FIXME: not useful??
    my ($self, $msg) = @_;
    $self->_wm_warn($msg);
    die sprintf "!! %s: %s\n", ref($self), $msg;
}

1;
