package Bio::Otter::Auth::Server::OIDCProvider::Authenticate;

use strict;
use warnings;

use Moo;
extends 'Web::Machine::Resource';

# consider using DrinkUp pattern instead
has cli_instance => ( is => 'rw' );
has state        => ( is => 'rw' );
has callback_uri => ( is => 'rw' );

sub init {
    my ($self, $args) = @_;
    foreach my $p ( qw{ cli_instance state callback_uri } ) {
        no strict 'refs';
        $p->($self, $args->{$p});
    }

    # Ensure session
    my $session = $self->request->session;
    unless ($session->{exists}) {
        $session->{exists}++;
    }

    $ENV{WM_DEBUG} = 1;         # TMP for testing

    return;
}

sub content_types_provided { [{'*/*' => sub { return 'Not expecting to render!'} }] }

# else we never get to moved_temporarily!
sub resource_exists    { return undef };
sub previously_existed { return 1     };

sub moved_temporarily {
    my ($self) = @_;
    my $base   = $self->request->base;
    # FIXME: via config
    my $redirect = join('/', $base, 'chooser');
    warn "Redirecting to: $redirect\n";
    return $redirect;
}

1;
