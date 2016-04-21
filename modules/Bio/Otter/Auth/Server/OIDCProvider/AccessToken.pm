package Bio::Otter::Auth::Server::OIDCProvider::AccessToken;

use strict;
use warnings;

use parent 'OAuth::Lite2::Model::AccessToken';

use JSON::WebToken qw( encode_jwt decode_jwt );
use Readonly       qw( Readonly );
use Try::Tiny      qw( try catch );

# Should these be via server.yaml?
Readonly my %CONFIG => (
    ACCESS_TOKEN_EXPIRATION => 24*60*60, # 1 day
    ACCESS_TOKEN_HMAC_KEY   => q{I SHOULD DEFINITELY BE SECRET!},
    );

sub create {
    my ($class, $auth_info) = @_;
    return unless $auth_info;

    # generate token string
    my $ts = time();
    my $token = encode_jwt (
        {
            auth_id    => $auth_info->id,
            expires_at => $ts + $CONFIG{ACCESS_TOKEN_EXPIRATION},
        },
        $CONFIG{ACCESS_TOKEN_HMAC_KEY},
    );

    # return instance
    return $class->new({
        auth_id    => $auth_info->id,
        token      => $token,
        expires_in => $CONFIG{ACCESS_TOKEN_EXPIRATION},
        created_on => $ts,
    });
}

sub validate {
    my ($class, $token) = @_;

    my $decoded;
    # if signature is invalid, JSON::WebToken cause error
    try {
        $decoded = decode_jwt(
            $token,
            $CONFIG{ACCESS_TOKEN_HMAC_KEY}
        ) or die 'failed to decode';
    }
    catch {
        warn "Error decoding token: '@_'\n";
    };
    return unless $decoded;

    # verify expiration
    return unless $decoded->{expires_at};
    return if     $decoded->{expires_at} < time();

    # return instance
    return $class->new({
        auth_id => $decoded->{auth_id},
        token => $token,
        expires_in => $CONFIG{ACCESS_TOKEN_EXPIRATION},
        created_on => $decoded->{expires_at} - $CONFIG{ACCESS_TOKEN_EXPIRATION},
    });
}

1;
