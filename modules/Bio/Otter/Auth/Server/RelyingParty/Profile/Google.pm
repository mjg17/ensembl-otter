package Bio::Otter::Auth::Server::RelyingParty::Profile::Google;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo::Role;

requires '_wm_warn';

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

sub decode_token_response {
    my ($self, $token, $response) = @_;
    $self->_wm_warn('Google decode_token_response not implemented yet.');
    return;
}

1;
