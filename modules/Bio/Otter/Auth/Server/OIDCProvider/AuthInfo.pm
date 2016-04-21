package Bio::Otter::Auth::Server::OIDCProvider::AuthInfo;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'OIDC::Lite::Model::AuthInfo';

has code_expires_at            => ( is => 'rw' );
has refresh_token_expires_at   => ( is => 'rw' );
has is_stored                  => ( is => 'rw' );
has userinfo_claims_serialised => ( is => 'rw', lazy => 1, builder => 1, trigger => 1 );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Carp                   qw( croak );
use Crypt::OpenSSL::Random qw( random_pseudo_bytes );
use Digest::SHA            qw( hmac_sha256_base64 );
use JSON                   qw( encode_json decode_json );
use Readonly               qw( Readonly );

use OIDC::Lite::Server::Scope;

Readonly my %CONFIG => (
    CODE_EXPIRATION          => 5*60,       # 5 mins
    CODE_HMAC_KEY            => q{SHOULD_I_BE_SECRET?},
    REFRESH_TOKEN_EXPIRATION => 7*24*60*60, # 1 week
    REFRESH_TOKEN_HMAC_KEY   => q{SHOULD_I_BE_SECRET?},
);

sub create {
    my ($class, %args) = @_;
    return unless %args;

    $args{id} = 0;
    $args{code} = q{};
    $args{code_expires_at} = 0;
    $args{refresh_token} = q{};
    $args{refresh_token_expires_at} = 0;

    if (my @scopes = split(/\s/, $args{scope})) {
        $args{userinfo_claims} = OIDC::Lite::Server::Scope->to_normal_claims(\@scopes);
    }

    return $class->new(\%args);
}

sub set_code {
    my $self = shift;

    $self->code_expires_at(time() + $CONFIG{CODE_EXPIRATION});
    my $code = hmac_sha256_base64(
        $self->client_id .
        $self->code_expires_at .
        unpack('H*', random_pseudo_bytes(32)),
        $CONFIG{CODE_HMAC_KEY});
    $self->code($code);

    return $code;
}

sub unset_code {
    my $self = shift;

    $self->code_expires_at(0);
    $self->code(q{});
    return;
}

sub set_refresh_token {
    my $self = shift;

    $self->refresh_token_expires_at(time() + $CONFIG{REFRESH_TOKEN_EXPIRATION});
    my $refresh_token = hmac_sha256_base64(
        $self->client_id .
        $self->refresh_token_expires_at .
        unpack('H*', random_pseudo_bytes(32)),
        $CONFIG{REFRESH_TOKEN_HMAC_KEY});
    $self->refresh_token($refresh_token);
    return $refresh_token;
}

sub _build_userinfo_claims_serialised {   ## no critic(Subroutines::ProhibitUnusedPrivateSubroutines)
    my ($self) = @_;
    return encode_json($self->userinfo_claims);
}

sub _trigger_userinfo_claims_serialised { ## no critic(Subroutines::ProhibitUnusedPrivateSubroutines)
    my ($self, $new_value) = @_;
    $self->userinfo_claims(decode_json($new_value));
    return $new_value;
}

1;
