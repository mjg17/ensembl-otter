package Bio::Otter::ZMap::Connect;

=head1 NAME - Bio::Otter::ZMap::Connect

=head1 DESCRIPTION

For  connecting  to ZMap  and  makes  the  X11::XRemote module  more
useable as a server.

=cut

use strict;
use warnings;

use Scalar::Util qw( weaken );

use XML::Simple;
use X11::XRemote;
use Tk::X;

my $DEBUG_CALLBACK = 0;
my $DEBUG_EVENTS   = 0;

=head1 METHODS

=head2 new

Creates a new Bio::Otter::ZMap::Connect Object.

=cut

sub new{
    my ($pkg, %arg_hash) = @_;
    my $self = { };
    bless($self, $pkg);
    $self->init(\%arg_hash);
    return $self;
}

sub init{
    my ($self, $arg_hash) = @_;
    my ($tk, $handler) = @{$arg_hash}{qw( -tk -handler )};

    $self->{'handler'} = $handler;
    weaken $self->{'handler'};
    my $widget = $self->{'_widget'} = $self->_widget($tk);

    my $self_ = $self; weaken $self_;
    $widget->bind('<Property>', [ \&_do_callback , $self_ ] );

    return;
}

=head2 connect_request

This maybe  used to  get the  string for registering  the server  as a
remote window  of the  zmap client.  ZMap  should honour  this request
creating a  client with  the window  id of the  request widget  as its
remote window.

=cut

sub connect_request{
    my ($self) = @_;

    my $fmt = q!<zmap>
 <request action="%s">
  <client xwid="%s" request_atom="%s" response_atom="%s"/>
 </request>
</zmap>!;

    return sprintf($fmt, 
                   "register_client", 
                   $self->server_window_id, 
                   $self->request_name,
                   $self->response_name
                   );
}

sub client_registered_response{
    my ($self) = @_;

    my $out  = {
        response => {
            client => [
                {
                    created => 1,
                    exists  => 1,
                }
            ]
        }
    };
    $self->protocol_add_meta($out);
    my $reponse =make_xml($out);

    return $reponse;
}

=head2 server_window_id

Just the window id of the request widget.

=cut


sub server_window_id{
    my ($self) = @_;
    return $self->widget->id();
}

=head2 xremote

The xremote Object [C<<< X11::XRemote >>>].

=cut

sub xremote{
    my ($self, $id) = @_;
    my $xr = $self->{'_xremote'};
    return $xr;
}



=head1 ERROR

 Currently just the one to help the user with consistency.

=head2 basic_error

Some xml which should be used in callback for error messages.

 sub cb {
   ...
   # On error
   my $errno = 404;
   my $xml = $Connect->basic_error("Unknown Command"); 
   ...
   return ($errno, $xml);
 }

=cut

sub handled_response {
    my ($self, $value) = @_;

    my $hash = {
        response => {
                handled => $value ? 1 : 0,
            }
        };
#    $self->protocol_add_request($hash);
    $self->protocol_add_meta($hash);
    return make_xml($hash);
}

sub basic_error {
    my ($self, $message) = @_;

    $message ||=  (caller(1))[3] . " was lazy";

    my $hash   = { 
        error => {
            message => [ $message ],
        }
    }; 
    $self->protocol_add_request($hash);
    $self->protocol_add_meta($hash);
    return make_xml($hash);
}

sub protocol_add_request {
    my ($self, $hash) = @_;

    $hash->{'request'} = [ xml_escape($self->_current_request_string) ];

    return;
}

sub protocol_add_meta {
    my ($self, $hash) = @_;

    $hash->{'meta'} = {
        display     => $ENV{DISPLAY},
        windowid    => $self->server_window_id,
        application => $self->xremote->application,
        version     => $self->xremote->version,
    };

    return;
}

sub request_name{
    return X11::XRemote::client_request_name;
}

sub response_name{
    return X11::XRemote::client_response_name;
}

sub widget{
    my ($self) = @_;
    my $widget = $self->{'_widget'};
    return $widget;
}

sub _widget{
    my ($self, $tk) = @_;
    my $qName = $self->request_name();
    my $sName = $self->response_name();
    # we create a new widget so our binding stay alive
    # and our users bindings don't get trampled on.
    my $widget =
        $tk
        ->Label( -text => "${qName}|${sName}|Widget" )
        ->pack(-side => 'left');

    # we need to wait until the widget is mapped by the x server so that we 
    # can reliably initialise the xremote protocol so we must wait for the
    # <Map> event

    my $mapped; # a flag used in waitVariable below to indicate that the widget is mapped

    $widget->bind(
        '<Map>' =>
        sub {
            $widget->packForget;
            my $xr = $self->{'_xremote'} =
                X11::XRemote->new( -server => 1, -id => $widget->id, );
            $xr->request_name($self->request_name);
            $xr->response_name($self->response_name);
            $mapped = 1;
        });

    # this call will essentially block until the widget is mapped and the
    # xremote protocol is initialised (the tk event loop will continue though)
    $widget->waitVariable(\$mapped);

    return $widget;
}

# ======================================================== #
#                      INTERNALS                           #
# ======================================================== #

my @xml_request_parse_parameters =
    (
     KeyAttr    => { feature => 'name' },
     ForceArray => [ 'feature', 'subfeature' ],
    );

sub _do_callback{
    my ($tk, $self) = @_;
    defined $self or return;
    my $id    = $tk->id();
    my $ev    = $tk->XEvent(); # Get the event
    my $state = ($ev->s ? $ev->s : 0); # assume zero (PropertyDelete I think)
    my $reqnm = $self->request_name(); # atom name of the request
    if ($state == PropertyDelete){
        warn "Event had state 'PropertyDelete', returning...\n" if $DEBUG_EVENTS;
        return ; # Tk->break
    }
    #====================================================================
    # DEBUG STUFF
    warn "//========== _do_callback ========== window id: $id\n" if $DEBUG_CALLBACK;
    if($DEBUG_EVENTS){
        foreach my $m('a'..'z','A'..'Z','#'){
            warn "Event on method '$m' - ". $ev->$m() . " " .sprintf("0x%lx", $ev->$m) . " \n" if $ev->$m();
        }
    }
    unless($ev->T eq 'PropertyNotify'){ warn "Odd Not a propertyNotify\n"; }
    unless($ev->d eq $reqnm){
        warn "Event was NOT for this.\n" if $DEBUG_CALLBACK;
        return ; # Tk->break
    }
    my $request_string = $self->xremote->request_string();
    $self->_current_request_string($request_string);
    warn "Event has request string $request_string\n" if $DEBUG_CALLBACK;
    #=========================================================
    my $request = XMLin($request_string, @xml_request_parse_parameters);
    my $reply;
    my $fstr  = $self->xremote->format_string;
    my $intSE = $self->basic_error("Internal Server Error");
    my $handler = $self->{'handler'};
    my $success = eval{ 
        X11::XRemote::block(); # this gets automatically unblocked for us, besides we have no way to do that!
        my ($status, $xmlstr) =
            defined $handler ? $handler->xremote_callback($request) : (500, $intSE);
        $reply = sprintf($fstr, $status, $xmlstr);
        1;
    };
    # $@ needs xml escaping!
    $reply ||= sprintf($fstr, 500, $self->basic_error("Internal Server Error $@"))
        unless $success;
    $reply ||= sprintf($fstr, 500, $intSE);
    $self->_drop_current_request_string;
    warn "Connect $reply\n" if $DEBUG_CALLBACK;
    $self->xremote->send_reply($reply);

    $handler->xremote_callback_post if defined $handler;

    return;
}

sub _drop_current_request_string {
    my ($self) = @_;

    $self->{'_current_request_string'} = undef;

    return;
}

sub _current_request_string {
    my ($self, $str) = @_;

    if ($str) {
        $self->{'_current_request_string'} = $str;
    }
    return $self->{'_current_request_string'};
}

sub send_commands {
    my ($self, $xremote, @xml) = @_;
    my @response_list = map { parse_response($_) } $xremote->send_commands(@xml);
    return @response_list;
}

sub parse_response {
    my ($response) = @_;
    my $delimit  = X11::XRemote::delimiter();
    my ($status, $xml) = split(/$delimit/, $response, 2);
    my $hash = XMLin($xml);
    my $parse = [ $status, $hash ];
    return $parse;
}

# ======================================================== #
# DESTROY: Hopefully won't need to do anything             #
# ======================================================== #
sub DESTROY{
    my ($self) = @_;
    warn "Destroying $self";
    return;
}

sub make_xml{
    my ($hash) = @_;
    my $xml = XMLout($hash, rootname => q{}, keeproot => 1);
    return $xml;
}

my $xml_escape_parser = XML::Simple->new(NumericEscape => 1);
sub xml_escape{
    my ($data) = shift;
    my $escaped = $xml_escape_parser->escape_value($data);
    return $escaped;
}

1;
__END__

=head1 A WORD OF WARNING

When  writing the callback to  be called  on receipt of a command, be
careful not to  send the origin window of the  command a command. This
will lead  to a race condition.   The original sender  will be waiting
for the reply  from the callback, while your window  will be sending a
command to a window which cannot respond.

The prevention of this race condition has been coded into this module
and the L<X11::XRemote> module and you will be warned of an C<Avoided 
race condition>.
problem.

The recommended solution to this common problem is to send yourself a
generated event.  This is very easy using L<Tk::event> and the C<<<
$widget->eventGenerate('<EVENT>', -when => 'tail') >>> function should
be sufficient for most cases.

 Example:

 my $callback = sub {
    my ($this, $request, $obj) = @_;
    if($request =~ /something_two_way/){
      $obj->widget->eventGenerate('<ButtonPress>', -when => 'tail');
    }
    return (200, "everything went well");
 };


=head1 AUTHOR

Ana Code B<email> anacode@sanger.ac.uk

=head1 SEE ALSO

L<X11::XRemote>, L<Tk::event>, L<perl>.

=cut

