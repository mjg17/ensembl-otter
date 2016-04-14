package Bio::Otter::Auth::Server::OIDCProvider::Authenticate;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::WebApp::Resource';

has cli_instance => ( is => 'ro' );
has state        => ( is => 'ro' );
has callback_uri => ( is => 'ro' );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

sub init {
    my ($self, $args) = @_;

    # Ensure session
    my $session = $self->request->session;
    unless ($session->{exists}) {
        $session->{exists}++;
    }

    return;
}

sub content_types_provided { return [{'*/*' => sub { return 'Not expecting to render!'} }] }

# We abuse this slightly as it is called early in the FSM
#
sub malformed_request {
    my ($self) = @_;

    # Stash the authenticate request parameters
    $self->request->session->{op} = {
        cli_instance => $self->cli_instance,
        state        => $self->state,
        callback_uri => $self->callback_uri,
    };
    return;
}

# else we never get to moved_temporarily!
sub resource_exists    { return       }
sub previously_existed { return 1     }

sub moved_temporarily {
    my ($self) = @_;

    my $chooser = $self->config->{ott_srv_rp}->{chooser_uri};

    # Pass our callback via session
    my $op_cb = $self->config->{ott_srv_op}->{callback_uri};
    $self->set_session_request_param('rp', 'callback_uri', $op_cb);

    $self->wm_warn("Redirecting to: ", $chooser);

    return $chooser;
}

1;
