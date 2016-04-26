package Bio::Otter::Auth::Server::OIDCProvider::Token;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::WebApp::Resource';

has client_id     => ( is => 'ro' );
has client_secret => ( is => 'ro' );
has grant_type    => ( is => 'ro' );
has redirect_uri  => ( is => 'ro' );
has code          => ( is => 'ro' );

has grant_types    => ( is => 'ro', default => sub { return [ qw( authorization_code ) ] } );
has grant_handlers => ( is => 'ro', lazy => 1, builder => 1 );
has grant_handler  => ( is => 'rw' );
has result         => ( is => 'rw' );

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Try::Tiny qw( try catch );

use OAuth::Lite2::Formatters;
use OAuth::Lite2::Server::Error;
use OIDC::Lite::Server::GrantHandlers;

use Bio::Otter::Auth::Server::DB::Handle;
use Bio::Otter::Auth::Server::OIDCProvider::DataHandler;

sub _build_grant_handlers { ## no critic(Subroutines::ProhibitUnusedPrivateSubroutines)
    my ($self) = @_;
    my %handlers;
    foreach my $gt ( @{$self->grant_types} ) {
        ## no critic(Modules::RequireExplicitInclusion)
        my $handler = OIDC::Lite::Server::GrantHandlers->get_handler($gt)
            or OAuth::Lite2::Server::Error::UnsupportedGrantType->throw;
        $handlers{$gt} = $handler;
    }
    return \%handlers;
}

sub allowed_methods        { return [qw(POST)] }
sub content_types_provided { return [{'application/json' => 'to_json'}] }

# We abuse this slightly as it is called early in the FSM
#
sub malformed_request {
    my ($self) = @_;

    my $grant_type = $self->grant_type;
    do { $self->wm_warn('grant_type not supplied');        return 1 } unless $grant_type;

    my $handler = $self->grant_handlers->{$grant_type};
    do { $self->wm_warn("grant_type '${grant_type}'not configured"); return 1 } unless $self->grant_type;
    $self->grant_handler($handler);

    do { $self->wm_warn('client_id not supplied' );        return 1 } unless $self->client_id;

    if ( $handler->is_required_client_authentication ) {
        do { $self->wm_warn('client_secret not supplied'); return 1 } unless $self->client_secret;
    }

    do { $self->wm_warn('code not supplied'             ); return 1 } unless $self->code;
    do { $self->wm_warn('redirect_uri not supplied'     ); return 1 } unless $self->redirect_uri;

    return;
}

sub is_authorized {
    my ($self, $auth_header) = @_;

    # Role?
    my $data_handler  = Bio::Otter::Auth::Server::OIDCProvider::DataHandler->new(
        dbh         => Bio::Otter::Auth::Server::DB::Handle->dbh,
        wm_resource => $self,
        );

    unless ($data_handler->validate_client($self->client_id, $self->client_secret, $self->grant_type)) {
        $self->wm_warn('client validation failed');
        return;
    }

    my $handler = $self->grant_handler();
    # Yuck - no methods?
    $handler->{client_id} = $self->client_id();
    $handler->{client_secret} = $self->client_secret();

    # Web::Simple mucks leaves input buffer used, so reset it if we can:
    my $input = $self->request->input;
    $input->seek(0, 0) if $input;

    my $result;
    try {
        $result = $handler->handle_request($data_handler);
    }
    catch {
        my $error = $_;
        $self->wm_warn("GrantHandler failed: '$error'");
    };
    return unless $result;

    $self->result($result);
    return 1;
}

sub process_post {
    my ($self) = @_;
    $self->response->body($self->to_json());
    return 1;
}

sub to_json {
    my ($self) = @_;
    my $formatter = OAuth::Lite2::Formatters->get_formatter_by_name("json");
    return $formatter->format($self->result());
}

1;
