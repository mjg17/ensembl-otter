package Bio::Vega::CloneFinder;

use strict;
use Bio::Otter::Lace::Locator;

my $component = 'clone';

#
# A module used by server script 'find_clones' to find things on clones
# (new API version)
#

use strict;

my $DEBUG=0; # do not show all SQL statements

sub new {
    my ($class, $dba, $qnames) = @_;

    my $self = bless {
        '_dba' => $dba,
        '_ql'  => ($qnames ? {map {($_ => [])} @$qnames } : {}),
    }, $class;

    return $self;
}

sub dba {
    my $self = shift @_;

    return $self->{_dba};
}

sub dbc {
    my $self = shift @_;

    return $self->dba->dbc();
}

sub qnames_locators {
#
# This is a HoL
# {query_name}[locators*]
#
    my $self = shift @_;

    return $self->{_ql};
}

sub register_feature {
    my ($self, $qname, $search_type, $feature) = @_;

    my $loc = Bio::Otter::Lace::Locator->new($qname, $search_type);

    my $csname = $feature->slice()->coord_system_name();

    $loc->assembly( ($csname eq 'chromosome')
        ? $feature->seq_region_name()
        : $feature->project('chromosome')->[0]->to_Slice()->seq_region_name()
    );

    $loc->component_names( ($csname eq $component)
        ? [ $feature->seq_region_name() ]
        : [ map { $_->to_Slice()->seq_region_name() } @{ $feature->project($component) } ]
    );

    my $locs = $self->qnames_locators()->{$qname} ||= [];
    push @$locs, $loc;
}

sub find_by_stable_ids {
    my $self = shift @_;

    my $dba      = $self->dba();
    my $meta_con = $dba->get_MetaContainer();

    my $prefix_primary = $meta_con->get_primary_prefix()
        || die "Missing prefix.primary in meta table";

    my $prefix_species = $meta_con->get_species_prefix()
        || die "Missing prefix.species in meta table";

    my $gene_adaptor           = $dba->get_GeneAdaptor();
    my $transcript_adaptor     = $dba->get_TranscriptAdaptor();
    my $exon_adaptor           = $dba->get_ExonAdaptor();

    foreach my $qname (keys %{$self->qnames_locators()}) {
        if(uc($qname) =~ /^$prefix_primary$prefix_species([TPGE])\d+/i){ # try stable_ids
            my $typeletter = $1;
            my $type;
            my $feature;

            eval {
                if($typeletter eq 'G') {
                    $type = 'gene_stable_id';
                    $feature = $gene_adaptor->fetch_by_stable_id($qname);
                } elsif($typeletter eq 'T') {
                    $type = 'transcript_stable_id';
                    $feature = $transcript_adaptor->fetch_by_stable_id($qname);
                } elsif($typeletter eq 'P') {
                    $type = 'translation_stable_id';
                    $feature = $transcript_adaptor->fetch_by_translation_stable_id($qname);
                } elsif($typeletter eq 'E') {
                    $type = 'exon_stable_id';
                    $feature = $exon_adaptor->fetch_by_stable_id($qname);
                }
            };
                # Just imagine: they raise an EXCEPTION to indicate nothing was found. Terrific!
            if($@) {
                # server_log("'$qname' looks like a stable id, but wasn't found.");
                # server_log($@)if $DEBUG;
            } else {
                $self->register_feature($qname, $type, $feature);
            }
        }
    } # foreach $qname
}

sub find_by_attributes {
    my ($self, $quoted_qnames, $table, $id_field, $code_hash, $adaptor_call) = shift @_;

    my $dba      = $self->dba();
    my $adaptor;

    while( my ($code,$qtype) = %$code_hash ) {
        my $sql = qq{
            SELECT $id_field, value
            FROM $table
            WHERE attrib_type_id = (SELECT attrib_type_id from attrib_type where code='$code')
              AND value in ($quoted_qnames)
        };

        my $sth = $dba->prepare($sql);
        $sth->execute();
        if( my ($feature_id, $qname) = $sth->fetchrow() ) {
            $adaptor ||= $dba->$adaptor_call; # only do it if we found something

            my $feature = $adaptor->fetch_by_dbID($feature_id);
            $self->register_feature($qname, $qtype, $feature);
        }
    }
}

sub find {
    my ($self, $unhide) = @_;

    my $quoted_qnames = join(', ', map {"'$_'"} keys %{$self->qnames_locators()} );

    $self->find_by_stable_ids();
    $self->find_by_attributes($quoted_qnames, 'gene_attrib', 'gene_id',
        { 'name' => 'gene_name', 'synonym' => 'gene synonym'},
        'get_GeneAdaptor');
    $self->find_by_attributes($quoted_qnames, 'transcript_attrib', 'transcript_id',
        { 'name' => 'transcript_name'},
        'get_TranscriptAdaptor');
}

sub generate_output {
    my ($self, $filter_atype) = @_;

    my $output_string = '';

    for my $qname (sort keys %{$self->qnames_locators()}) {
        my $locators = $self->qnames_locators()->{$qname};
        my $count = 0;
        for my $loc (@$locators) {
            my $asm = $loc->assembly();
            if(!$filter_atype || ($filter_atype eq $asm)) {
                $output_string .= join("\t",
                    $qname, $loc->qtype(),
                    join(',', @{$loc->component_names()}),
                    $loc->assembly())."\n";
                $count++;
            }
        }
        if(!$count) {
            $output_string .= "$qname\n"; # no matches for this qname
        }
    }

    return $output_string;
}

1;

