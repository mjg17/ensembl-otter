package Bio::Otter::Auth::Server::WebApp;

use strict;
use warnings;

use Web::Simple;

use Bio::Otter::Auth::Server::OIDCProvider;
use Bio::Otter::Auth::Server::RelyingParty;

sub dispatch_request {
    my ($self) = @_;
    return (

        sub ( GET  + /authenticate + ?:cli_instance~&:state~&:callback_uri~ ) {
            return Bio::Otter::Auth::Server::OIDCProvider->authenticate_handler($_[1]);
        },
        sub ( POST + /token ) {
            Bio::Otter::Auth::Server::OIDCProvider->token_handler()
        },
        sub ( GET + /token ) {  # TMP for testing
            Bio::Otter::Auth::Server::OIDCProvider->token_handler()
        },

        sub ( GET  + /chooser ) {
            Bio::Otter::Auth::Server::RelyingParty->chooser_handler()
        },
        sub ( GET  + /external/:ext_service ) {
            Bio::Otter::Auth::Server::RelyingParty->external_handler($_[1])
        },
        sub ( GET  + /callback/:ext_service ) {
            Bio::Otter::Auth::Server::RelyingParty->callback_handler($_[1])
        },
        );
}

__PACKAGE__->run_if_script;

1;
