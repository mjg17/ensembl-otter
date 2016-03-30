package Bio::Otter::Auth::Server::RelyingParty;

use strict;
use warnings;

use Bio::Otter::Auth::Server::WebUtils qw( web_machine );

# Strictly speaking we shouldn't need to do this, but CLASS->isa() is unreliable after
# use_package_optimistically() in Web::Machine otherwise.
#
use Bio::Otter::Auth::Server::RelyingParty::Chooser;
use Bio::Otter::Auth::Server::RelyingParty::External;

sub chooser_handler {
    my ($pkg) = @_;
    return web_machine('Bio::Otter::Auth::Server::RelyingParty::Chooser', []);
}

sub external_handler {
    my ($pkg, $params) = @_;
    return web_machine('Bio::Otter::Auth::Server::RelyingParty::External', [ %$params ]);
}

sub callback_handler {
    my ($pkg, $params) = @_;
    return sub { [ 200, [ 'Content-type' => 'text/plain' ], [ 'RP_callback, ext_service: ', $params->{ext_service} ] ] };
}

1;
