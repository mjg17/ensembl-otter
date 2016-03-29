package Test::Bio::Otter::Auth::Server::CHI;

use Bio::Otter::Server::Config;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server';

BEGIN {
    __PACKAGE__->expected_class('CHI::Driver::DBI');
}

sub build_attributes { return; } # none

sub our_args {
    my $config = Bio::Otter::Server::Config->Server;
    return [ %{$config->{ott_srv}->{CHI}} ];
}


1;
