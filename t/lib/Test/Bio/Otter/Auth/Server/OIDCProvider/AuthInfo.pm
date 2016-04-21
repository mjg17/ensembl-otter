package Test::Bio::Otter::Auth::Server::OIDCProvider::AuthInfo;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server';

sub our_args {
    return [ {
        user_id   => 1,
        client_id => q{sample_client_id},
        scope     => q{openid},
        id        => 0,
             } ];
}

sub build_attributes { return {
    code_expires_at          => '1012013',
    refresh_token_expires_at => '1012013',
    is_stored                => 1,
                       }; } # none

sub userinfo_claims_serialised : Tests {
    my ($test) = @_;
    my $ai = $test->our_object;

    $ai->userinfo_claims([qw(a z)]);
    is($ai->userinfo_claims_serialised, '["a","z"]', 'serialise');

    $ai->userinfo_claims_serialised('["x","y","blue"]');
    is_deeply($ai->userinfo_claims, [qw(x y blue)], 'deserialise');

    return;
}

1;
