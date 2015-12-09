#!/usr/bin/env perl

### seq_stats.pl

use strict;
use warnings;
use Hum::FastaFileIO;

{
    my $in = Hum::FastaFileIO->new(\*ARGV);
    my $lengths = [];
    while (my $seq = $in->read_one_sequence) {
        push(@$lengths, $seq->sequence_length);
    }
    print_stat("Sequence lengths", $lengths);
}

sub print_stat {
    my ($label, $list) = @_;

    print "$label\n";

    my $count = @$list;
    @$list = sort {$a <=> $b} @$list;
    my $total = 0;
    my $min = $list->[0];
    my $max = $list->[$#$list];
    foreach my $n (@$list) {
        $total += $n;
    }
    my $med = $list->[$count / 2];
    my $pattern = "%7s  %9d\n";
    printf $pattern, 'count', $count;
    printf $pattern, 'min',   $min;
    printf $pattern, 'avg',   $total / $count;
    printf $pattern, 'med',   $med;
    printf $pattern, 'max',   $max;
}


__END__

=head1 NAME - seq_stats.pl

=head1 AUTHOR

James Gilbert B<email> jgrg@sanger.ac.uk

