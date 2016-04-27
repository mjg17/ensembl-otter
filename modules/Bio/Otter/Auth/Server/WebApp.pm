package Bio::Otter::Auth::Server::WebApp;

use strict;
use warnings;

use Web::Simple;                # becomes our parent

use Module::Load qw( load );
use Plack::Builder;
use Plack::Request;

use Bio::Otter::Auth::Server::OIDCProvider;
use Bio::Otter::Auth::Server::WebApp::Machine;

# TEMP workaround for Apache2 / Otter::Paths only run once ??
#
use Bio::Otter::Auth::Server::OIDCProvider::Authenticate;
use Bio::Otter::Auth::Server::OIDCProvider::Authorise;
use Bio::Otter::Auth::Server::OIDCProvider::Token;
use Bio::Otter::Auth::Server::RelyingParty::Callback;
use Bio::Otter::Auth::Server::RelyingParty::Chooser;
use Bio::Otter::Auth::Server::RelyingParty::External;
use Bio::Otter::Auth::Server::RelyingParty::Success;
#use Bio::Otter::Auth::Server::RelyingParty::Error;

# These shenanigans are to give Plack::Request first dibs on body
# parameters, before Web::Simple (not-so-simple?) gobbles them
# up.
# Subsequent Plack::Requests then know how to Do The Right Thing.

around 'to_psgi_app' => sub { ##  no critic(Subroutines::ProhibitCallsToUndeclaredSubs)
    my ($orig, $self) = (shift, shift);
    my $app = $self->$orig(@_);
    builder {
        enable sub {
            my $app = shift;
            sub {
                my $env = shift;

                # do preprocessing
                my $req = Plack::Request->new($env);
                $req->body_parameters;

                my $res = $app->($env);

                # no postprocessing

                return $res;
            };
        };
        $app;
    };
};

sub _web_machine {
    my ($self, $resource, $path_params, $query_params) = @_;

    $resource = 'Bio::Otter::Auth::Server::' . $resource;
    load $resource;

    my %params = ( %{ $path_params // {} }, %{ $query_params // {} } );

    my $machine = Bio::Otter::Auth::Server::WebApp::Machine->new(
        resource      => $resource,
        config        => $self->config,
        request_params => \%params,
        );
    return $machine->to_app;
}

sub dispatch_request {     ## no critic (Subroutines::RequireArgUnpacking)
    my ($self) = @_;
    return (

        sub ( GET  + /authenticate + ?:client_id~&:cli_instance~&:state~&:callback_uri~&:response_type~&:scope~ ) {
            return $self->_web_machine('OIDCProvider::Authenticate', $_[1]);
        },
        sub ( POST + /token + %:client_id~&:client_secret~&:grant_type~&:redirect_uri~&:code~ ) {
            return $self->_web_machine('OIDCProvider::Token', $_[1]);
        },
        sub ( GET + /op/authorise ) {
            return $self->_web_machine('OIDCProvider::Authorise', $_[1]);
        },

        sub ( GET  + /chooser + ?:callback_uri~ ) {
            return $self->_web_machine('RelyingParty::Chooser', $_[1]);
        },
        sub ( GET  + /external/:ext_service ) {
            return $self->_web_machine('RelyingParty::External', $_[1]);
        },
        sub ( GET  + /callback/:ext_service + ?:state~&:code~ ) {
            return $self->_web_machine('RelyingParty::Callback', $_[1], $_[2]);
        },
        sub ( GET + /rp/success ) {
            return $self->_web_machine('RelyingParty::Success');
        },
        sub ( GET + /rp/error ) {
            return $self->_web_machine('RelyingParty::Error');
        },
        );
}

Bio::Otter::Auth::Server::WebApp->run_if_script;

1;
