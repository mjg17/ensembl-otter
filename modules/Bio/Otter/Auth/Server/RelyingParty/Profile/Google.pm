package Bio::Otter::Auth::Server::RelyingParty::Profile::Google;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo::Role;

requires 'wm_warn';

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use OIDC::Lite::Model::IDToken;

sub decode_token_response {
    my ($self, $token, $response) = @_;

    my $id_token = OIDC::Lite::Model::IDToken->load($token->id_token);
    unless ($id_token) {
        $self->wm_warn('could not load id_token');
        return;
    }

    # # this is only necessary if we are not communicating directly with Google over https.
    #
    # unless ($id_token->verify) {
    #     $self->wm_warn('id_token verification failed');
    #     return;
    # }

    return {
        provider     => 'Google',
        access_token => $token->access_token,
        identifier   => $id_token->payload->{email},
        extra        => { email_verified => !!$id_token->payload->{email_verified} },
    }
}

1;
