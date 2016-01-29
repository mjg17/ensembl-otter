package Web::Machine::I18N;
# ABSTRACT: The I18N support for HTTP information

use strict;
use warnings;

use parent 'Locale::Maketext';

our $VERSION = '0.16';

1;

__END__

=pod

=head1 NAME

Web::Machine::I18N - The I18N support for HTTP information

=head1 VERSION

version 0.16

=head1 SYNOPSIS

  use Web::Machine::I18N;

=head1 DESCRIPTION

This is basic support for internationalization of HTTP
information. Currently it just provides response bodies
for HTTP errors.

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
