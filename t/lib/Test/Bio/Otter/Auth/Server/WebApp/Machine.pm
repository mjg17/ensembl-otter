package Test::Bio::Otter::Auth::Server::WebApp::Machine;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server';

use Bio::Otter::Auth::Server::WebApp::Resource;

sub build_attributes { return; } # none

sub our_args {
    return [
        resource => 'Bio::Otter::Auth::Server::WebApp::Resource',
    ]
}

1;
