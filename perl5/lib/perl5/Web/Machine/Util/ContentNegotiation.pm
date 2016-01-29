package Web::Machine::Util::ContentNegotiation;
# ABSTRACT: Module to handle content negotiation

use strict;
use warnings;

our $VERSION = '0.16';

use Scalar::Util qw[ blessed ];

use Web::Machine::Util qw[
    first
    pair_key
];

use Sub::Exporter -setup => {
    exports => [qw[
        choose_media_type
        match_acceptable_media_type
        choose_language
        choose_charset
        choose_encoding
    ]]
};

my $ACTIONPACK = Web::Machine::Util::get_action_pack;
my $NEGOTIATOR = $ACTIONPACK->get_content_negotiator;

sub choose_media_type {
    my ($provided, $header) = @_;
    $NEGOTIATOR->choose_media_type( $provided, $header );
}

sub match_acceptable_media_type {
    my ($to_match, $accepted) = @_;
    my $content_type = blessed $to_match ? $to_match : $ACTIONPACK->create( 'MediaType' => $to_match );
    if ( my $acceptable = first { $content_type->match( pair_key( $_ ) ) } @$accepted ) {
        return $acceptable;
    }
    return;
}

sub choose_language {
    my ($provided, $header) = @_;
    return 1 if scalar @$provided == 0;
    $NEGOTIATOR->choose_language( $provided, $header );
}

sub choose_charset {
    my ($provided, $header) = @_;
    return 1 if scalar @$provided == 0;
    $NEGOTIATOR->choose_charset( [ map { ref $_ ? pair_key( $_ ) : $_ } @$provided ], $header );
}

sub choose_encoding {
    my ($provided, $header) = @_;
    $NEGOTIATOR->choose_encoding( [ keys %$provided ], $header );
}

1;

__END__

=pod

=head1 NAME

Web::Machine::Util::ContentNegotiation - Module to handle content negotiation

=head1 VERSION

version 0.16

=head1 SYNOPSIS

  use Web::Machine::Util::ContentNegotiation;

=head1 DESCRIPTION

This module provides a set of functions used in content negotiation.

=head1 FUNCTIONS

=over 4

=item C<choose_media_type ( $provided, $header )>

Given an ARRAY ref of media type strings and an HTTP header, this will
return the matching L<HTTP::Headers::ActionPack::MediaType> instance.

=item C<match_acceptable_media_type ( $to_match, $accepted )>

Given a media type string to match and an ARRAY ref of media type objects,
this will return the first matching one.

=item C<choose_language ( $provided, $header )>

Given a list of language codes and an HTTP header value, this will attempt
to negotiate the best language match.

=item C<choose_charset ( $provided, $header )>

Given a list of charset name and an HTTP header value, this will attempt
to negotiate the best charset match.

=item C<choose_encoding ( $provided, $header )>

Given a list of encoding name and an HTTP header value, this will attempt
to negotiate the best encoding match.

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
