package Bio::Otter::Auth::Server::OIDCProvider::DataHandler;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'OIDC::Lite::Server::DataHandler';

has wm_resource => ( is => 'ro', required => 1, handles => [ qw( request ) ] );
has dbh         => ( is => 'ro', required => 1 );

has config            => ( is => 'ro', builder => 1, lazy => 1 );
has auth_info_adaptor => ( is => 'ro', builder => 1, lazy => 1 );

has client      => ( is => 'rw' );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use OIDC::Lite::Model::IDToken;

use Bio::Otter::Auth::Server::OIDCProvider::AccessToken;
use Bio::Otter::Auth::Server::OIDCProvider::AuthInfo;
use Bio::Otter::Auth::Server::DB::AuthInfoAdaptor;
use Bio::Otter::Server::Config;

sub _build_config {    ## no critic(Subroutines::ProhibitUnusedPrivateSubroutines)
    my ($self) = @_;
    return $self->wm_resource->config->{ott_srv_op};
}

sub _build_auth_info_adaptor {    ## no critic(Subroutines::ProhibitUnusedPrivateSubroutines)
    my ($self) = @_;
    return Bio::Otter::Auth::Server::DB::AuthInfoAdaptor->new($self->dbh);
}


sub validate_client_by_id {
    my ($self, $client_id) = @_;
    $self->_warn("blindly validated client_id '$client_id'.");
    $self->client($client_id);  # FIXME: may need more than this
    return 1;
}

sub validate_client_for_authorization {
    my ($self, $client_id, $response_type) = @_;
    $self->_warn("validated client_id '$client_id', response_type '$response_type' for authorization");
    return 1;
}

sub validate_redirect_uri {
    my ($self, $client_id, $redirect_uri) = @_;
    $self->_warn("validated client_id '$client_id' for redirect_uri '$redirect_uri'");
    return 1;
}

# Do we need this for CSRF Protection?
sub require_server_state {
    my ($self, $scope) = @_;
    return 0;
}

sub validate_server_state {
    my ($self, $server_state, $client_id) = @_;
    $self->_warn("validated server_state '$server_state' for client_id '$client_id'");
    return 1;
}

sub validate_scope {
    my ($self, $client_id, $scope) = @_;
    $scope //= '<not-set>';
    $self->_warn("validated client_id '$client_id' for scope '$scope'");
    return 1;
}

# Optional request param are not validated
sub validate_display {
    my ($self, $display) = @_;
    return 1;
}

sub validate_prompt {
    my ($self, $prompt) = @_;
    return 1;
}

sub validate_max_age {
    my ($self, $param) = @_;
    return 1;
}

sub validate_ui_locales {
    my ($self, $ui_locales) = @_;
    return 1;
}

sub validate_claims_locales {
    my ($self, $claims_locales) = @_;
    return 1;
}

sub validate_id_token_hint {
    my ($self, $param) = @_;
    return 1;
}

sub validate_login_hint {
    my ($self, $param) = @_;
    return 1;
}

sub validate_request {
    my ($self, $param) = @_;
    return 1;
}

sub validate_request_uri {
    my ($self, $param) = @_;
    return 1;
}

sub validate_acr_values {
    my ($self, $param) = @_;
    return 1;
}

sub get_user_id_for_authorization {
    my ($self) = @_;

    # This is where we do the translation.

    my $rp_auth_info = $self->wm_resource->auth_info;
    my $ext_id   =    $rp_auth_info->{identifier};
    my $provider = lc $rp_auth_info->{provider};

    my $user = Bio::Otter::Server::Config->Access->user_by_alias($provider, $ext_id);
    die "no alias for ($provider:$ext_id)\n" unless $user;

    my $user_id = $user->email;
    $self->_warn("translated ($provider:$ext_id) to '$user_id'");
    return $user_id;
}

sub create_id_token {
    my ($self) = @_;

    my $ts = time();
    my $payload = {
        sub => $self->get_user_id_for_authorization(),
        iss => $self->config->{id_token}->{iss},
        iat => $ts,
        exp => $ts + $self->config->{id_token}->{expires_in},
        aud => $self->client,
    };
    $payload->{nonce} = $self->request->param('nonce') if $self->request->param('nonce');

    return OIDC::Lite::Model::IDToken->new(
        header => {
            typ => q{JOSE},
            alg => q{RS256},
            kid => 1,
        },
        payload => $payload,
        key     => $self->config->{id_token}->{priv_key},
    );
}

# Needs to return a OIDC::Lite::Model::AuthInfo or subclass.
# Later passed to create_or_update_access_token().
#
sub create_or_update_auth_info {
    my ($self, %args) = @_;
    return unless ( %args &&
                    $self->request &&
                    $self->request->param('redirect_uri'));

    $args{redirect_uri} = $self->request->param('redirect_uri');

    my $info = Bio::Otter::Auth::Server::OIDCProvider::AuthInfo->create(%args);
    $info->set_code;
    $self->auth_info_adaptor->store_or_update($info);

    return $info;
}

sub get_auth_info_by_id {
    my ($self, $id) = @_;
    return $self->auth_info_adaptor->fetch_by_id($id);
}

sub get_auth_info_by_code {
    my ($self, $code) = @_;
    return $self->auth_info_adaptor->fetch_by_code($code);
}

sub get_auth_info_by_refresh_token {
    my ($self, $refresh_token) = @_;
    return $self->auth_info_adaptor->fetch_by_refresh_token($refresh_token);
}


sub create_or_update_access_token {
    my ($self, %args) = @_;
    return unless $args{auth_info};

    my $auth_info = $args{auth_info};
    # If the request is for token endpoint, the code in AuthInfo is deleted
    if ($self->request->param('grant_type') and
        $self->request->param('grant_type') eq q{authorization_code}) {

        $auth_info->set_refresh_token;
        $auth_info->unset_code;
        $self->auth_info_adaptor->store_or_update($auth_info);
    }
    return Bio::Otter::Auth::Server::OIDCProvider::AccessToken->create($args{auth_info});
}


sub get_access_token {
    my ($self, $token) = @_;
    return Bio::Otter::Auth::Server::OIDCProvider::AccessToken->validate($token);
}

sub _warn {
    my ($self, @messages) = @_;
    warn sprintf('[w] %s: ', ref($self)), @messages, "\n";
    return;
}

1;
