package Bio::Otter::Auth::Server::DB::AuthInfoAdaptor;

use strict;
use warnings;

use parent 'Bio::Otter::Lace::DB::Adaptor';

use Carp qw( carp );

sub columns { return qw(
    id
    client_id
    user_id
    scope
    refresh_token
    code
    redirect_uri
    id_token
    userinfo_claims_serialised
    code_expires_at
    refresh_token_expires_at
); }

sub key_column_name       { return 'id'; }
sub key_is_auto_increment { return 1;    }

sub object_class { return 'Bio::Otter::Auth::Server::OIDCProvider::AuthInfo'; }

## no critic(Modules::RequireExplicitInclusion)
my $all_columns = __PACKAGE__->all_columns;
my $all_placeholders = join(',', map { '?' } __PACKAGE__->columns);
## use critic(Modules::RequireExplicitInclusion)

sub check_object {
    my ($self, $auth_info) = @_;
    $self->SUPER::check_object($auth_info); # confesses on error
    $auth_info->id(undef) unless $auth_info->id; # ensure 0 => undef for caller
    return $auth_info;
}

sub fetch_by_id {
    my ($self, $id) = @_;
    return $self->fetch_by_key($id);
}

sub fetch_by_code {
    my ($self, $code) = @_;
    my $sth = $self->_fetch_by_code_sth;
    return $self->fetch_by($sth, "multiple auth_info entries for code '%s'", $code);
}

sub fetch_by_refresh_token {
    my ($self, $refresh_token) = @_;
    my $sth = $self->_fetch_by_refresh_token_sth;
    return $self->fetch_by($sth, "multiple auth_info entries for refresh_token '%s'", $refresh_token);
}

sub _fetch_by_code_sth          { return shift->_prepare_canned('fetch_by_code'); }
sub _fetch_by_refresh_token_sth { return shift->_prepare_canned('fetch_by_refresh_token'); }

sub SQL {
    return {
    store =>            qq{ INSERT INTO auth_info ( ${all_columns} )
                                                   VALUES ( ${all_placeholders} )
                          },
    update =>            q{ UPDATE auth_info
                               SET
                                   id                         = ?
                                 , client_id                  = ?
                                 , user_id                    = ?
                                 , scope                      = ?
                                 , refresh_token              = ?
                                 , code                       = ?
                                 , redirect_uri               = ?
                                 , id_token                   = ?
                                 , userinfo_claims_serialised = ?
                                 , code_expires_at            = ?
                                 , refresh_token_expires_at   = ?
                             WHERE id = ?
                          },
    delete =>            q{ DELETE FROM auth_info WHERE id = ?
                          },
    fetch_by_key =>     qq{ SELECT ${all_columns} FROM auth_info WHERE id = ?
                          },
    fetch_by_code =>    qq{ SELECT ${all_columns} FROM auth_info WHERE code = ?
                          },
    fetch_by_refresh_token =>
                        qq{ SELECT ${all_columns} FROM auth_info WHERE refresh_token = ?
                          },
    };
}

1;
