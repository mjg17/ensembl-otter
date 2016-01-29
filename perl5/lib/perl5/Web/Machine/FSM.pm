package Web::Machine::FSM;
# ABSTRACT: The State Machine runner

use strict;
use warnings;

our $VERSION = '0.16';

use IO::Handle::Util 'io_from_getline';
use Plack::Util;
use Try::Tiny;
use HTTP::Status qw[ is_error ];
use Web::Machine::I18N;
use Web::Machine::FSM::States qw[
    start_state
    is_status_code
    is_new_state
    get_state_name
    get_state_desc
];

sub new {
    my ($class, %args) = @_;
    bless {
        tracing        => !!$args{'tracing'},
        tracing_header => $args{'tracing_header'} || 'X-Web-Machine-Trace'
    } => $class
}

sub tracing        { (shift)->{'tracing'} }
sub tracing_header { (shift)->{'tracing_header'} }

sub run {
    my ( $self, $resource ) = @_;

    my $DEBUG;
    if ( $ENV{WM_DEBUG} ) {
        $DEBUG
            = $ENV{WM_DEBUG} eq 'diag'
            ? sub { Test::More::diag( $_[0] ) }
            : sub { warn "$_[0]\n" };
    }

    my $request  = $resource->request;
    my $response = $resource->response;
    my $metadata = {};
    $request->env->{'web.machine.context'} = $metadata;

    my @trace;
    my $tracing = $self->tracing;

    my $state = start_state;

    try {
        while (1) {
            $DEBUG->( 'entering '
                    . get_state_name($state) . ' ('
                    . get_state_desc($state)
                    . ')' )
                if $DEBUG;
            push @trace => get_state_name( $state ) if $tracing;
            my $result = $state->( $resource, $request, $response, $metadata );
            if ( ! ref $result ) {
                # TODO:
                # We should be I18N this
                # specific error
                # - SL
                $DEBUG->( '! ERROR with ' . ( $result || 'undef' ) )
                    if $DEBUG;
                $response->status( 500 );
                $response->header( 'Content-Type' => 'text/plain' );
                $response->body( [ "Got bad state: " . ($result || 'undef') ] );
                last;
            }
            elsif ( is_status_code( $result ) ) {
                $DEBUG->( '.. terminating with ' . ${$result} ) if $DEBUG;
                $response->status( $$result );

                if ( is_error( $$result ) && !$response->body ) {
                    # NOTE:
                    # this will default to en, however I
                    # am not really confident that this
                    # will end up being sufficient.
                    # - SL
                    my $lang = Web::Machine::I18N->get_handle( $metadata->{'Language'} || 'en' )
                        or die "Could not get language handle for " . $metadata->{'Language'};
                    $response->header( 'Content-Type' => 'text/plain' );
                    $response->body([ $lang->maketext( $$result ) ]);
                }

                if ($DEBUG) {
                    require Data::Dumper;
                    local $Data::Dumper::Terse     = 1;
                    local $Data::Dumper::Indent    = 1;
                    local $Data::Dumper::Useqq     = 1;
                    local $Data::Dumper::Deparse   = 1;
                    local $Data::Dumper::Quotekeys = 0;
                    local $Data::Dumper::Sortkeys  = 1;
                    $DEBUG->( Data::Dumper::Dumper( $request->env ) );
                    $DEBUG->( Data::Dumper::Dumper( $response->finalize ) );
                }

                last;
            }
            elsif ( is_new_state( $result ) ) {
                $DEBUG->( '-> transitioning to ' . get_state_name($result) )
                    if $DEBUG;
                $state = $result;
            }
        }
    } catch {
        # TODO:
        # We should be I18N the errors
        # - SL
        $DEBUG->($_) if $DEBUG;

        if ( $request->logger ) {
            $request->logger->( { level => 'error', message => $_ } );
        }

        $response->status( 500 );

        # NOTE:
        # this way you can handle the
        # exception if you like via
        # the finish_request call below
        # - SL
        $metadata->{'exception'} = $_;
    };

    $self->filter_response( $resource )
        unless $request->env->{'web.machine.streaming_push'};
    try {
        $resource->finish_request( $metadata );
    }
    catch {
        $DEBUG->($_) if $DEBUG;

        if ( $request->logger ) {
            $request->logger->( { level => 'error', message => $_ } );
        }

        $response->status( 500 );
    };
    $response->header( $self->tracing_header, (join ',' => @trace) )
        if $tracing;

    $response;
}

sub filter_response {
    my $self = shift;
    my ($resource) = @_;

    my $response = $resource->response;
    my $filters = $resource->request->env->{'web.machine.content_filters'};

    # XXX patch Plack::Response to make _body not private?
    my $body = $response->_body;

    for my $filter (@$filters) {
        if (ref($body) eq 'ARRAY') {
            $response->body( [ map { $filter->($_) } @$body ] );
            $body = $response->body;
        }
        else {
            my $old_body = $body;
            $body = io_from_getline sub { $filter->($old_body->getline) };
            $response->body($body);
        }
    }

    if (ref($body) eq 'ARRAY'
     && !Plack::Util::status_with_no_entity_body($response->status)) {
        $response->header(
            'Content-Length' => Plack::Util::content_length($body)
        );
    }
}

1;

__END__

=pod

=head1 NAME

Web::Machine::FSM - The State Machine runner

=head1 VERSION

version 0.16

=head1 SYNOPSIS

  use Web::Machine::FSM;

=head1 DESCRIPTION

This is the heart of the L<Web::Machine>, this is the thing
which runs the state machine whose states are contained in the
L<Web::Machine::FSM::States> module.

=for Pod::Coverage filter_response

=head1 METHODS

=over 4

=item C<new ( %params )>

This accepts two C<%params>, the first is a boolean to
indicate if you should turn on tracing or not, and the second
is optional name of the HTTP header in which to place the
tracing information.

=item C<tracing>

Are we tracing or not?

=item C<tracing_header>

Accessor for the HTTP header name to store tracing data in.
This default to C<X-Web-Machine-Trace>.

=item C<run ( $resource )>

Given a L<Web::Machine::Resource> instance, this will execute
the state machine.

=back

=head1 SEE ALSO

=over 4

=item L<Web Machine state diagram|https://github.com/Webmachine/webmachine/wiki/Diagram>

=back

=head1 AUTHORS

=over 4

=item *

Stevan Little <stevan@cpan.org>

=item *

Dave Rolsky <autarch@urth.org>

=back

=head1 CONTRIBUTORS

=for stopwords Andreas Marienborg Andrew Nelson Arthur Axel 'fREW' Schmidt Carlos Fernando Avila Gratz Fayland Lam George Hartzell Gregory Oschwald Jesse Luehrs John SJ Anderson Mike Raynham Nathan Cutler Olaf Alders Thomas Sibley

=over 4

=item *

Andreas Marienborg <andreas.marienborg@gmail.com>

=item *

Andrew Nelson <anelson@cpan.org>

=item *

Arthur Axel 'fREW' Schmidt <frioux@gmail.com>

=item *

Carlos Fernando Avila Gratz <cafe@q1software.com>

=item *

Fayland Lam <fayland@gmail.com>

=item *

George Hartzell <hartzell@alerce.com>

=item *

Gregory Oschwald <goschwald@maxmind.com>

=item *

Jesse Luehrs <doy@tozt.net>

=item *

John SJ Anderson <genehack@genehack.org>

=item *

Mike Raynham <enquiries@mikeraynham.co.uk>

=item *

Mike Raynham <mike.raynham@spareroom.co.uk>

=item *

Nathan Cutler <ncutler@suse.cz>

=item *

Olaf Alders <olaf@wundersolutions.com>

=item *

Thomas Sibley <tsibley@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Infinity Interactive, Inc..

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
