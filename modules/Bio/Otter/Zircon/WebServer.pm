
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
    $new->_info_callback($arg_hash{'-info_callback'});
    $new->log_context(   $arg_hash{'-log_context'});

    $new->launch_app;
    return $new;
}

sub zircon_trace_prefix {
    my ($self) = @_;
    return 'B:O:Z:WebServer';
}

Readonly my %_dispatch_table => (
    info => { method => \&_info },
    );

sub command_dispatch {
    my ($self, $command) = @_;
    return $_dispatch_table{$command};
}

sub _info {
    my ($self, $view_handler, $key_entity) = @_;

    $self->logger->debug("_info");
    my $info = $self->_info_callback->();
    my $reply =
        $info
        ? [ undef, $info ]
        : $self->protocol->message_command_failed('no info... failed');
    return $reply;
}

sub _info_callback {
    my ($self, @args) = @_;
    ($self->{'_info_callback'}) = @args if @args;
    my $_info_callback = $self->{'_info_callback'};
    return $_info_callback;
}

sub default_log_context {
    return '-B-O-Z-WebServer unnamed-';
}

1;

=head1 AUTHOR

Ana Code B<email> anacode@sanger.ac.uk
