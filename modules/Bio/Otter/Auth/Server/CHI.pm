package Bio::Otter::Auth::Server::CHI;

use strict;
use warnings;

use parent qw(CHI);

use DBI;

use Bio::Otter::Server::Config;

sub new {
    my ($pkg, $config) = @_;

    # FIXME: error checking
    my $dbspec = delete $config->{DBI}->{dbspec};
    my $database = Bio::Otter::Server::Config->Database($dbspec);
    my @spec_DBI = $database->spec_DBI;

    my $dbh = DBI->connect(@spec_DBI);
    return $pkg->SUPER::new(%$config, dbh => $dbh);
}

1;
