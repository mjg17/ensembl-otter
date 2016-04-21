package Test::Bio::Otter::Auth::Server::DB::AuthInfoAdaptor;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server';

use Bio::Otter::Auth::Server::OIDCProvider::AuthInfo;
use Bio::Otter::Auth::Server::DB::Handle;

sub build_attributes { return; } # none

sub our_args {
    return [
        Bio::Otter::Auth::Server::DB::Handle->dbh,
        ];
}

sub _expected {
    return (
    { client_id => 'ABC-1234', user_id => 'spqr1@sanger.ac.uk', scope => 'test' },
    { client_id => 'ABC-1234', user_id => 'xyz89@sanger.ac.uk', scope => 'test' },
    { client_id => 'DEF-1234', user_id => 'xyz89@sanger.ac.uk', scope => 'profile' },
    );
}

sub Adaptor : Test(6) {
    my ($test) = @_;

    my $ai_ad = $test->our_object;

    my @exp = $test->_expected;

    subtest 'Add' => sub {
        my $instance;
        foreach my $e ( @exp ) {
            ++$instance;
            subtest "Add $instance" => sub {
                my $ai = Bio::Otter::Auth::Server::OIDCProvider::AuthInfo->create(%$e);
                ok(not($ai->is_stored), "not stored");
                ok($ai_ad->store_or_update($ai),  "store_or_update");
                ok($ai->is_stored,      "is_stored");
                ok($ai->id,             "has id");
                note('id: ', $ai->id);
                $e->{'_id'} = $ai->id;
                done_testing;
            };
        }
        done_testing;
    };

    $test->_test_loop('Retrieve by id', \@exp,
               sub {
                   my ($e, $id, $ai) = @_;
                   foreach my $field ( qw[ client_id user_id scope ] ) {
                       is($ai->$field(), $e->{$field}, $field);
                   }
               });

    $test->_test_loop('Update', \@exp,
               sub {
                   my ($e, $id, $ai) = @_;
                   $e->{'code'} = $ai->set_code;
                   ok($ai_ad->store_or_update($ai), "store_or_update");
               });

    $test->_test_loop('Fetch by code', \@exp,
               sub {
                   my ($e, $id) = @_;
                   my $ai = $ai_ad->fetch_by_code($e->{'code'});
                   ok($ai, "fetch_by_code");
                   is($ai->id, $id, 'id');
                   is($ai->code, $e->{'code'}, 'code');
                   ok($ai->code_expires_at, 'code_expires_at set');
                   $e->{refresh_token} = $ai->set_refresh_token;
                   $ai->unset_code;
                   ok($ai_ad->store_or_update($ai), "store_or_update");
               });

    $test->_test_loop('Fetch by refresh_token', \@exp,
               sub {
                   my ($e, $id) = @_;
                   my $ai = $ai_ad->fetch_by_refresh_token($e->{'refresh_token'});
                   ok($ai, "fetch_by_refresh_token");
                   is($ai->id, $id, 'id');
                   ok(not($ai->code), 'code cleared in previous test');
                   is($ai->refresh_token, $e->{'refresh_token'}, 'refresh_token');
                   ok($ai->refresh_token_expires_at, 'refresh_token_expires_at set');
               });

    $test->_test_loop('Delete', \@exp,
               sub {
                   my ($e, $id, $ai) = @_;
                   ok($ai_ad->delete($ai), 'delete');
                   ok(not($ai->is_stored), 'no longer stored');
                   my $ai_gone = $ai_ad->fetch_by_key($id);
                   is($ai_gone, undef, 'gone');
               });

    return;
}

sub _test_loop {
    my ($test, $desc, $exp, $iter_sub) = @_;
    subtest $desc => sub {
        foreach my $e ( @$exp ) {
            my $id = $e->{'_id'};
            my $ai_ad = $test->our_object;
            subtest "$desc for id $id" => sub {
                my $ai = $ai_ad->fetch_by_key($id);
                ok($ai, "fetch");
                $iter_sub->($e, $id, $ai);
                done_testing;
            };
        }
        done_testing;
    };
}

1;
