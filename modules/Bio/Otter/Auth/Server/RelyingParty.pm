package Bio::Otter::Auth::Server::RelyingParty;

use strict;
use warnings;

sub chooser_handler {
    my ($pkg, $params) = @_;
    return sub { [ 200, [ 'Content-type' => 'text/plain' ], [ 'RP_chooser' ] ] };
}

sub callback_handler {
    my ($pkg, $params) = @_;
    return sub { [ 200, [ 'Content-type' => 'text/plain' ], [ 'RP_callback, ext_service: ', $params->{ext_service} ] ] };
}

1;
