#!/usr/local/bin/perl

# based on parse_chr21 script from Stephen Keenan (which parsed gtf
# and wrote otter_xml) which was in turn based on parse_chr21 script
# in ensembl-otter/scripts/conversion which writes into an ensembl db.

use Getopt::Long;
use strict;

use Bio::Otter::AnnotatedGene;
use Bio::Otter::AnnotatedTranscript;
use Bio::Otter::TranscriptRemark;
use Bio::Otter::GeneRemark;
use Bio::Otter::Author;
use Bio::Otter::GeneInfo;
use Bio::Otter::TranscriptInfo;
use Bio::Otter::GeneName;
use Bio::Otter::TranscriptClass;
use Bio::Otter::Evidence;

use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Exon;
use Bio::EnsEMBL::Transcript;

use Data::Dumper;

$| = 1;

$Getopt::Long::ignorecase=0;

my $phelp;
my $help;

my $chr='21';
my $chrstart=1;
my $chrend=44626493;
my $type='chr21';
my $suffix='RIKEN';

my $opt_i='chr21-20030701_catalog_20031010_gtf.table';
my $opt_o='chr21.xml';

my $author='Riken';
my $email='taylor@gsc.riken.go.jp';

my $opt_P;

GetOptions(
	   'chr:s',      \$chr,
	   'chrstart:i', \$chrstart,
	   'chrend:i',   \$chrend,
	   'type:s',     \$type,
	   'i:s',        \$opt_i,
	   'o:s',        \$opt_o,
	   'author:s',   \$author,
	   'email:s',    \$email,
	   'suffix:s',   \$suffix,
	   'P',          \$opt_P,

	   'help', \$phelp,
	   'h', \$help,
	   );

# help
if($phelp){
    exec('perldoc', $0);
    exit 0;
}
if($help){
    print<<ENDOFTEXT;
gtf2xml.pl
  -chr             char   chromosome name ($chr)
  -chrstart        num    start coordinate ($chrstart)
  -chrend          num    end coordinate ($chrend)
  -type            char   assembly type ($type)
  -i               file   input filename ($opt_i)
  -o               file   output filename ($opt_o)
  -author          char   author label ($author)
  -email           char   email address for feedback on database ($email)
  -suffix          char   group suffix to append to gene_names ($suffix)

  -h                      this help
  -help                   perldoc help

  -P                      parse input file only
ENDOFTEXT
    exit 0;
}

my %genes;
my %gene;

my %other;
my %gtf_keys;
my %category;

# assumes gtf has categories labelled by GENE
# (otter now stores data with option to label
# TRANSCRIPT by transcript_class)
my %standard_category;
%standard_category=(
		    'Known'=>1,
		    'Novel_CDS'=>1,
		    'Novel_Transcript'=>1,
		    'Putative'=>1,
		    'Pseudogene'=>1,
		    'Processed_pseudogene'=>1,
		    'Unprocessed_pseudogene'=>1,
		    'Polymorphic'=>1,
		    'Ig_Pseudogene_Segment'=>1,
		    'Ig_Segment'=>1,
		    );
my %map_category;
%map_category=(
	       'known'=>'Known',
	       'novel_CDS'=>'Novel_CDS',
	       'novel_transcript'=>'Novel_Transcript',
	       'pseudogene'=>'Pseudogene',
	       'processed_pseudogene'=>'Processed_pseudogene',
	       'unprocessed_pseudogene'=>'Unprocessed_pseudogene',
	       'putative_gene'=>'Putative',
	       'polymorphic'=>'Polymorphic',
	       'ig_pseudogene_segment'=>'Ig_Pseudogene_Segment',
	       'ig_segment'=>'Ig_Segment',
	       'predicted'=>'Predicted',
	       );

my $nok=0;
my $n1=0;
my $nn=0;
open(IN,$opt_i) || die "cannot open $opt_i";
while(<IN>){
  next if /^#/;
  next if /^\s*$/;
  chomp;
  my @arr = split ( ' ', $_, 9 );
  my $start  = $arr[3];
  my $end    = $arr[4];
  my $strand = $arr[6];

  my @arr2=split(/\;/,$arr[8]);
  my %hashy;
  foreach my $str (@arr2) {
    my($key, $val)=split(' ',$str,2);
    $key=~s/ //g;
    $key=~s/\"//g;
    $val=~s/\"//g;
    if($key ne "Description"){
      $key=~s/\t//g;
      $val=~s/^ +//;
      $val=~s/ +$//;
      $val=~s/\t//g;
    }else{
      $val=~s/\t/ /g;
    }
    $gtf_keys{$key}++;
    if($key eq 'gene_category'){
      if($map_category{$val}){
	$val=$map_category{$val};
      }
      if($standard_category{$val}){
	$standard_category{$val}++;
      }else{
	$category{$val}++;
      }
    }
    $hashy{$key}=$val;
  }

  # check for expected param
  if(!$hashy{'gene_id'}){
    print "FATAL: no gene_id for ".join(',',@arr)."\n";
    exit 0 unless $opt_P;
  }elsif(!$hashy{'transcript_id'}){
    print "WARN: no transcript_id for ".join(',',@arr)."\n";
  }

  # check gene_id is sensible and change if necessary
  my $gene_id = $hashy{'gene_id'};
  if($gene_id=~/(RNA|CDS)$/){
    print "gene_id ends in $1 - check parsing ".join(',',@arr)."\n";
    exit 0 unless $opt_P;
  }
  $hashy{'gene_id'} = $gene_id;

  # hack to fix errors:
  if($end==$start-1){
    $n1++;
    $end=$start+100;
  }elsif($end<$start){
    $nn++;
  }else{
    $nok++;
  }

  my $transcript_id = $hashy{'transcript_id'};
  my %exonhash;
  $exonhash{'start'}  = $start;
  $exonhash{'end'}    = $end;
  $exonhash{'strand'} = $strand;
  $exonhash{'values'} = \%hashy;

  if($arr[2] eq "exon"){
    if(!defined($genes{$gene_id}->{$transcript_id}->{'values'})){
      $genes{$gene_id}->{$transcript_id}->{'values'}=\%hashy;
    }
    if(!defined($genes{$gene_id}->{$transcript_id}->{exons})){
      $genes{$gene_id}->{$transcript_id}->{'exons'}=[];
    }
    push(@{$genes{$gene_id}->{$transcript_id}->{'exons'}},\%exonhash);
  }elsif($arr[2] eq "CDS"){
    if(!defined($genes{$gene_id}->{$transcript_id}->{cds})){
      $genes{$gene_id}->{$transcript_id}->{cds}=[];
    }
    push(@{$genes{$gene_id}->{$transcript_id}->{'cds'}},\%exonhash);
  }elsif($arr[2] eq "gene"){
    # don't expect to see this line, but in ERI GTF, seems to have
    # some extra information
    if(!defined($gene{$gene_id}->{$transcript_id}->{gene})){
      $gene{$gene_id}->{$transcript_id}->{gene}=[];
    }
    push(@{$gene{$gene_id}->{$transcript_id}->{'gene'}},\%exonhash);
  }else{
    # count occurances of other gtf types
    $other{$arr[2]}++;
  }
}
close(IN);
print "$nok coords ok; $n1 coords -1 error; $nn coords reversed\n";
if($n1){
  print "WARN: -1 end coordinates were made start + 100\n";
}

print scalar(keys(%genes))," genes found\n";
my $nt=0;
foreach my $gene_id (keys %genes){
  $nt+=scalar(keys %{$genes{$gene_id}});
}
print "$nt transcripts found\n";

# look for entries in gene, not in genes
foreach my $gene_id (keys %gene){
  if(!$genes{$gene_id}){
    print "$gene_id does not have exon or cds entries\n";
  }
  foreach my $transcript_id (keys %{$gene{$gene_id}}){
    if(!$genes{$gene_id}->{$transcript_id}){
      print "$gene_id:$transcript_id does not have exon or cds entries\n";
    }
  }
}

print "Following keys were found\n";
foreach my $key (keys %gtf_keys){
  print "  $key: $gtf_keys{$key}\n";
}
print "\n\n";

print "Following gene categories were found\n";
foreach my $key (sort keys %standard_category){
  print "  $key: ". ($standard_category{$key} - 1) ." [standard]\n";
}
print "\n";
foreach my $key (sort keys %category){
  print "  $key: ".$category{$key}." [unknown]\n";
}
print "\n\n";

if(scalar(keys %other)){
  print "WARN - found line types other than CDS and exon in gtf file\n";
  foreach my $other (keys %other){
    print "  $other: $other{$other}\n";
  }
}

exit 0 if $opt_P;

open(OUT,">$opt_o") || die "could not open $opt_o";

# write fake XML assembly block
print OUT qq{
<otter>

<sequence_set>
<sequence_fragment>
  <id>fake</id>
  <chromosome>$chr</chromosome>
  <accession>fake</accession>
  <version>1</version>
  <assembly_start>$chrstart</assembly_start>
  <assembly_end>$chrend</assembly_end>
  <fragment_ori>1</fragment_ori>
  <fragment_offset>1</fragment_offset>
  <assembly_type>$type</assembly_type>
</sequence_fragment>

};

my $author = new Bio::Otter::Author(
    -name  => $author,
    -email => $email
);

foreach my $gene_id (keys %genes){
  my $gene     = new Bio::Otter::AnnotatedGene;
  my $geneinfo = new Bio::Otter::GeneInfo;   
  $gene->gene_info($geneinfo);

  my @transcript_ids = keys %{ $genes{$gene_id} };
  my %values = %{ $genes{$gene_id}{$transcript_ids[0]}{values} };

  my $gene_type=$values{'gene_category'};
  if(!$gene_type){$gene_type='Novel_Transcript';}
  # never actually gets into the XML... (transcript level)
  $gene->type($gene_type);

  my $gene_name=$gene_id;
  if($suffix){$gene_name.=".$suffix";}
  if(defined($values{'Locus'}) && $values{'Locus'} ne $gene_id){
    if($suffix){
      print "WARN Locus $gene_id defined ($values{'Locus'}) ignored as using suffix\n";
    }else{
      $gene_name=$values{'Locus'};
    }
  }
  print STDERR "Gene id $gene_name ($gene_id)\n";

  $geneinfo->name(new Bio::Otter::GeneName(-name=>$gene_name));

  $geneinfo->author($author);

  # OTT ids should NOT be defined by gtf
  #SMJS Added and then removed
  #$gene->stable_id($gene_id);

  my @evidence;
  if(0){
    # load evidence if exists
    # WRONG BEHAVIOUR - should be at transcript or exon level
    if($values{'SID'}){
      foreach my $word (split /\|/, $values{SID}){
	my $type;
	if($word=~/^\w+\.\d+$/){
	  $type='cDNA';
	}else{
	  $type='Protein';
	}
	push @evidence,( new Bio::Otter::Evidence(-name=>$word,-type=>$type));
      }
    }
  }

  if($values{'Description'}){
    my $remark=new Bio::Otter::GeneRemark(-remark=>$values{'Description'});
    $geneinfo->remark($remark);
  }
   
  # transcripts
  my $t_index='1';
  foreach my $transcript_id (@transcript_ids){
    my $tran     = new Bio::Otter::AnnotatedTranscript;
    my $traninfo = new Bio::Otter::TranscriptInfo;
    $tran->transcript_info($traninfo);
    $gene->add_Transcript($tran);

    my %tvalues = %{$genes{$gene_id}{$transcript_id}{values}};
      

    # NOT WORKING
    if(0){
      if(scalar(@evidence)){
	foreach my $evi (@evidence){
	  $traninfo->evidence($evi);
	}
      }
    }

    # transcript_name is create from gene_name;
    # original transcript_id is stored in remark
    my $transcript_name=next_transcript_name($gene_name,\$t_index);
    print STDERR " Transcript id $transcript_name ($transcript_id)\n";
    $traninfo->name($transcript_name);
    my $remark;
    if($suffix){
      $remark="$suffix name: $transcript_id";
    }else{
      $remark="GTF name: $transcript_id";
    }
    $traninfo->remark(new Bio::Otter::TranscriptRemark(-remark=>$remark));
    # recognise some tags and save as remarks
    if($values{'complete_CDS'}){
      my $remark;
      if($suffix){
	$remark="$suffix";
      }else{
	$remark="GTF";
      }
      $remark.=" remark: ";
      if($values{'complete_CDS'} eq 'yes'){
	$remark.='complete_CDS';
      }elsif($values{'complete_CDS'} eq 'no'){
	$remark.='incomplete_CDS';
      }else{
	print "WARN undefined value for 'complete_CDS'\n";
	exit 0;
      }
      $traninfo->remark(new Bio::Otter::TranscriptRemark(-remark=>$remark));
    }

    $traninfo->author($author);

    # OTT ids should NOT be defined by gtf
    #$tran->stable_id($transcript_id);

    my @exons=@{$genes{$gene_id}{$transcript_id}{'exons'}};
    foreach my $exon (@exons) {
      my $newexon = new Bio::EnsEMBL::Exon(
					   -start  => $exon->{start},
					   -end    => $exon->{end},
					   -strand => $exon->{strand},
					   );

      $tran->add_Exon($newexon);
      $newexon->phase(-1);
    }

    # build translation on top of transcripts where defined
    if(defined @{ $genes{$gene_id}{$transcript_id}{cds}}){
      my @cdsexons = @{$genes{$gene_id}{$transcript_id}{cds}};
      my $mincds = -1;
      my $maxcds = -1;
      foreach my $cdsex (@cdsexons) {
	if ( $mincds == -1 ) {
	  $mincds = $cdsex->{start};
	}
	if ( $maxcds == -1 ) {
	  $maxcds = $cdsex->{end};
	}
	if ( $cdsex->{start} < $mincds ) {
	  $mincds = $cdsex->{start};
	}
	if ( $cdsex->{end} > $maxcds ) {
	  $maxcds = $cdsex->{end};
	}
      }
      my $translation=new Bio::EnsEMBL::Translation;
      $tran->translation($translation);
      my @exons=@{$tran->get_all_Exons};
      foreach my $ex (@exons){
	if($mincds >= $ex->start && $mincds <= $ex->end ){
	  if($ex->strand==1){
	    $translation->start_Exon($ex);
	    $translation->start($mincds-$ex->start+1);
	  }else {
	    $translation->end_Exon($ex);
	    $translation->end($ex->end-$mincds+1);
	  }
	}
	if($maxcds >= $ex->start && $maxcds <= $ex->end){
	  if($ex->strand == 1){
	    $translation->end_Exon($ex);
	    $translation->end($maxcds-$ex->start+1);
	  }else{
	    $translation->start_Exon($ex);
	    $translation->start( $ex->end - $maxcds + 1 );
	  }
	}
      }
      # Finally the phase
      if ( $exons[0]->strand == 1 ) {
	@exons = sort { $a->start <=> $b->start } @exons;
      }else{
	@exons = sort { $b->start <=> $a->start } @exons;
      }
      my $found_start = 0;
      my $found_end   = 0;
      my $phase       = 0;
      foreach my $exon (@exons) {
	if ( $found_start && !$found_end ) {
	  $exon->phase($phase);
	  $exon->end_phase( ( $exon->length + $exon->phase ) % 3 );
	  $phase = $exon->end_phase;
	}
	if($translation->start_Exon==$exon){
	  $exon->phase($phase);
	  
	  # Is this right?
	  #$exon->end_phase(($exon->length+$exon->phase) % 3);
	  #Changed from exon->length
	  $exon->end_phase((($exon->length-$translation->start+1)
			    +$exon->phase )%3);
	  $phase=$exon->end_phase;
	  $found_start=1;
	}
	if ( $translation->end_Exon == $exon ) {
	  $found_end = 1;
	}
      }
    }

    # map gene type onto transcript class
    if($gene->type =~ /seudogene/){
      $traninfo->class( new Bio::Otter::TranscriptClass(-name=>$gene_type));
    }elsif($gene->type =~ /utative/){
      $traninfo->class( new Bio::Otter::TranscriptClass(-name=>"Putative"));
    }elsif($tran->translation){
      $traninfo->class( new Bio::Otter::TranscriptClass(-name=>"Coding"));
    }else{
      $traninfo->class( new Bio::Otter::TranscriptClass(-name =>"Transcript"));
    }

  }
  
  $gene->gene_info->known_flag(1) if $gene->type eq 'Known';

  eval { 
    print OUT $gene->toXMLString . "\n"; 
  };
  if ($@) {
    print STDERR $gene->stable_id, "\n$@";
  }
}

print OUT qq{
</sequence_set>
</otter>
};

exit 0;

# creates indexed transcript form gene_name and increments counter.
sub next_transcript_name{
  my($gn,$ti)=@_;
  my $tn;
  if($$ti<10){
    $tn=$gn.'-00'.$$ti;
  }elsif($$ti<100){
    $tn=$gn.'-0'.$$ti;
  }else{
    $tn=$gn.'-'.$$ti;
  }
  $$ti++;
  return $tn;
}

sub read_gi_to_know_gene_names {
    my ($filename) = @_;

    my %typehash;
    my $type = 'Known';
    if ( !-e $filename ) {
        die "Couldn't open mapping file $filename\n";
    }
    open FPMAP, "<$filename" or die "Couldn't open mapping file $filename";
    while (<FPMAP>) {
        chomp;

        #if (/Sequence : \"(.*)\"/) {
        my ( $id, $known_gene_name ) = split ( /\t/, $_ );
        $id =~ s/\mRNA$//;
        $typehash{$id} = $known_gene_name || 'none';

    }
    close FPMAP;

    return \%typehash;
}

__END__

=pod

=head1 db_count.pl

=head1 DESCRIPTION

=head1 EXAMPLES

=head1 FLAGS

=over 4

=item -h

Displays short help

=item -help

Displays this help message

=back

=head1 VERSION HISTORY

=over 4

=item 16-JAN-2003

B<th> released first version

=back

=head1 BUGS

=head1 AUTHOR

B<Tim Hubbard> Email th@sanger.ac.uk

=cut
