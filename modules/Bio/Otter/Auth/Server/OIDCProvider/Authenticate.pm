package Bio::Otter::Auth::Server::OIDCProvider::Authenticate;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::WebApp::Resource';

# consider using DrinkUp pattern instead
has cli_instance => ( is => 'rw' );
has state        => ( is => 'rw' );
has callback_uri => ( is => 'rw' );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

sub init {
    my ($self, $args) = @_;
    foreach my $p ( qw{ cli_instance state callback_uri } ) {
        no strict 'refs';       ## no critic(TestingAndDebugging::ProhibitNoStrict)
        $p->($self, $args->{$p});
    }

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
    my $base   = $self->request->base;
    $base =~ s|/$||;            # remove trailing slash
    # FIXME: via config
    my $redirect = join('/', $base, 'chooser');
    warn "Redirecting to: $redirect\n";
    return $redirect;
}

1;
