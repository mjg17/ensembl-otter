package Bio::Otter::Auth::Server::WebApp;

use strict;
use warnings;

use Web::Simple;                # becomes our parent

use Module::Load qw( load );

use Bio::Otter::Auth::Server::OIDCProvider;
use Bio::Otter::Auth::Server::WebApp::Machine;

sub _web_machine {
    my ($self, $resource, $request_params) = @_;

    $resource = 'Bio::Otter::Auth::Server::' . $resource;
    load $resource;

    my $machine = Bio::Otter::Auth::Server::WebApp::Machine->new(
        resource      => $resource,
        config        => $self->config,
        request_params => $request_params // {},
        );
    return $machine->to_app;
}

sub dispatch_request {     ## no critic (Subroutines::RequireArgUnpacking)
    my ($self) = @_;
    return (

        sub ( GET  + /authenticate + ?:cli_instance~&:state~&:callback_uri~ ) {
            return $self->_web_machine('OIDCProvider::Authenticate', $_[1]);
        },
        sub ( POST + /token ) {
            Bio::Otter::Auth::Server::OIDCProvider->token_handler()
        },
        sub ( GET + /token ) {  # TMP for testing
            Bio::Otter::Auth::Server::OIDCProvider->token_handler()
        },

        sub ( GET  + /chooser ) {
            return $self->_web_machine('RelyingParty::Chooser');
        },
        sub ( GET  + /external/:ext_service ) {
            return $self->_web_machine('RelyingParty::External', $_[1]);
        },
        sub ( GET  + /callback/:ext_service ) {
            return $self->_web_machine('RelyingParty::Callback', $_[1]);
        },
        );
}

Bio::Otter::Auth::Server::WebApp->run_if_script;

1;
