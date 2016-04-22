package Bio::Otter::Auth::Server::OIDCProvider::Authorise;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::WebApp::Resource';

has auth_info => ( is => 'rw' );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Try::Tiny qw( try catch );
use URI;

use OAuth::Lite2::Util qw( build_content );
use OIDC::Lite::Server::AuthorizationHandler;

use Bio::Otter::Auth::Server::DB::Handle;
use Bio::Otter::Auth::Server::OIDCProvider::DataHandler;

sub content_types_provided { return [{'*/*' => sub { return 'Not expecting to render!'} }] }

# We abuse this slightly as it is called early in the FSM
#
sub malformed_request {
    my ($self) = @_;

    my $conflict = $self->grab_session_request_param('op', 'auth_info');
    unless ($self->auth_info) {
        $self->wm_warn('No auth_info');
        return 1;
    }

    return;
}

# else we never get to moved_temporarily!
sub resource_exists    { return       }
sub previously_existed { return 1     }

sub moved_temporarily {
    my ($self) = @_;

    my $uri = $self->config->{ott_srv_op}->{error_uri};

    my $data_handler  = Bio::Otter::Auth::Server::OIDCProvider::DataHandler->new(
        dbh         => Bio::Otter::Auth::Server::DB::Handle->dbh,
        wm_resource => $self,
        );
    my $authz_handler = OIDC::Lite::Server::AuthorizationHandler->new(
        data_handler   => $data_handler,
        response_types => [ 'code' ],
        );

    my ($ah_response, $error);
    try {
        $authz_handler->handle_request();
        # validate_csrf here
        $ah_response = $authz_handler->allow();
    }
    catch {
        $error = $_;
        $self->wm_warn("AuthzHandler failed: '$error'");
    };

    return $uri unless $ah_response;

    # success!!
    $self->request->session_options->{'change_id'} = 1;

    if (my $cb = $self->request->session->{op}->{callback_uri}) {
        $uri = $cb;
    } else {
        $self->wm_warn('no callback in session');
    }

    my $uri_obj = URI->new($uri);
    $uri_obj->query(build_content($ah_response->{query}));
    $uri = $uri_obj->as_string;

    $self->wm_warn("Redirecting to: '$uri'");
    return $uri;
}

1;
