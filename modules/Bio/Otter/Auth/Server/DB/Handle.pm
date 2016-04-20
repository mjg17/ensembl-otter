package Bio::Otter::Auth::Server::DB::Handle;

use strict;
use warnings;

use DBI;
use Log::Any::Adapter('Stderr'); # tmp

use Bio::Otter::Server::Config;

{
    # dbh is a singleton

    my $dbh;

    sub dbh {
        my ($pkg) = @_;
        return $dbh //= $pkg->_connect_dbh;
    }
}

sub _connect_dbh {
    my $config = Bio::Otter::Server::Config->Server;
    my $dbi_spec = $config->{ott_srv}->{DBI};

    # FIXME: error checking
    my $database = Bio::Otter::Server::Config->Database($dbi_spec->{dbspec});
    my @spec_DBI = $database->spec_DBI($dbi_spec->{database});

    my $dbh = DBI->connect(@spec_DBI);
    return $dbh;
}

1;
