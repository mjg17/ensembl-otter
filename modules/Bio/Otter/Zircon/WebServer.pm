
package Bio::Otter::Zircon::WebServer;

use strict;
use warnings;

use Readonly;
use Scalar::Util 'weaken';

use parent qw(
    Zircon::Protocol::Server::AppLauncher
    Bio::Otter::Log::WithContextMixin
);

our $ZIRCON_TRACE_KEY = 'ZIRCON_WEB_SERVER_TRACE';

sub new {
    my ($pkg, %arg_hash) = @_;
    my $new = $pkg->SUPER::new(
        -program         => 'web_server',
        -app_tag         => 'otter_web',
        -serialiser      => 'JSON',
        -peer_socket_opt => 'peer_socket',
        %arg_hash,
        );
    # $new->_ping_callback($arg_hash{'-ping_callback'});
    $new->log_context(        $arg_hash{'-log_context'});

    $new->launch_app;
    return $new;
}

sub zircon_trace_prefix {
    my ($self) = @_;
    return 'B:O:Z:WebServer';
}

Readonly my %_dispatch_table => (
    ping => { method => \&_ping },
    );

sub command_dispatch {
    my ($self, $command) = @_;
    return $_dispatch_table{$command};
}

sub _ping {
    my ($self, $view_handler, $key_entity) = @_;

    $self->logger->debug("_ping");
    # $self->_ping_callback->($stuff);
    return $self->protocol->message_ok('got ping, thanks.');
}

# sub _ping_callback {
#     my ($self, @args) = @_;
#     ($self->{'_ping_callback'}) = @args if @args;
#     my $_ping_callback = $self->{'_ping_callback'};
#     return $_ping_callback;
# }

sub default_log_context {
    return '-B-O-Z-WebServer unnamed-';
}

1;

=head1 AUTHOR

Ana Code B<email> anacode@sanger.ac.uk
