package Bio::Otter::Auth::Server::CHI;

use strict;
use warnings;

use parent qw(CHI);

use DBI;
use Log::Any::Adapter('Stderr'); # tmp

use Bio::Otter::Server::Config;

sub new {
    my ($pkg, %config) = @_;

    my $dbi_spec = delete $config{DBI};
    if ($dbi_spec) {
        # FIXME: error checking
        my $database = Bio::Otter::Server::Config->Database($dbi_spec->{dbspec});
        my @spec_DBI = $database->spec_DBI($dbi_spec->{database});

        my $dbh = DBI->connect(@spec_DBI);
        $config{dbh} = $dbh;
    }

    return $pkg->SUPER::new(%config);
}

1;
