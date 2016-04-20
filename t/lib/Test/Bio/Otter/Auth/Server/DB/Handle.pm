package Test::Bio::Otter::Auth::Server::DB::Handle;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server';

sub build_attributes { return; } # none

sub setup       { return; }  # don't let OtterTest::Class do its OO stuff
sub constructor { return; }  # --"--

sub dbh : Tests {
    my ($test) = @_;

    my $dbh = $test->class->dbh;
    isa_ok($dbh, 'DBI::db');

    return;
}

1;
