#!/usr/bin/env perl

=head1 NAME

00_FailBulkSkips.t - a catchall test which fails if any of the automatic skips are triggered.

=head1 DESCRIPTION

Other ensembl-otter tests in t/ make use of various mechanisms to automatically skip tests
if the environment is insufficient. This is fine during development, but before release
it is important that no tests have been automatically skipped. This test fails if any of the
automatic skips it knows about are (would have been) active.

=cut

use strict;
use warnings;

use Test::More;
use Test::Requires;
use Try::Tiny;

use Test::Otter;

=head1 DETAILS

=head2 Required modules

There should be a C<require_ok> test for every module which is the subject of L<Test::Requires>
(whether directly at C<use> time, or via C<test_requires()>).

=cut

require_ok('Bio::EnsEMBL::Analysis::Tools::BlastDBTracking');
require_ok('Bio::EnsEMBL::Pipeline::DBSQL::Finished::DBAdaptor');
require_ok('DBD::mysql');

=head2 Test::Otter *_or_skipall

Each L<Test::Otter> C<{something}_or_skipall> function should be factored so that it calls
C<check_{something}> to compute the assertion. Each C<check_{something}> should then be tested here.

=cut

my $error;
$error = Test::Otter::check_db();       is($error, undef, 'expect direct database access to work');
$error = Test::Otter::check_data_dir(); is($error, undef, 'expect to have otter data dir');

done_testing;

1;

=head1 TODO

This is a maintenance headache.

It would be nice to have an automatic way of optionally failing the tests themselves.
Perhaps the automatic skips should be fatal unless an environment variable is set?

=head1 AUTHOR

Ana Code B<email> anacode@sanger.ac.uk

=cut

# Local Variables:
# mode: perl
# End:

# EOF