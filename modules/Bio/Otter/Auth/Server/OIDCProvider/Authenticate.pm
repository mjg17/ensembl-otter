package Bio::Otter::Auth::Server::OIDCProvider::Authenticate;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::WebApp::Resource';

has cli_instance => ( is => 'rw' );
has state        => ( is => 'rw' );
has callback_uri => ( is => 'rw' );

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

# else we never get to moved_temporarily!
sub resource_exists    { return       }
sub previously_existed { return 1     }

sub moved_temporarily {
    my ($self) = @_;

    my $chooser = $self->config->{ott_srv_rp}->{chooser_uri};
    warn "Redirecting to: $chooser\n";
    return $chooser;
}

1;
