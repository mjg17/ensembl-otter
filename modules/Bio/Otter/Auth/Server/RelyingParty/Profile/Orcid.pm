package Bio::Otter::Auth::Server::RelyingParty::Profile::Orcid;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo::Role;

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

sub decode_token_response {
    my ($self, $token, $response) = @_;

    return {
        provider     => 'ORCID',
        access_token => $token->access_token,
        identifier   => $token->{orcid},
        name         => $token->{name},
    }
}

1;
