package Evi::EviDisplay;

# A window showing a transcript and supporting evidence
#
# lg4

my $bind_ok = 1;

my $ystep = 16;
my $rel_exon_thickness = 0.5; # in practice - from 0.1 to 0.9
my $half_delta	= $ystep*$rel_exon_thickness/2;

my $current_contour_color = 'red';
my $selection_color    = '#9ea2ff';
my $highlighting_color = 'yellow';

my @alternating_colors = ('white','#eeeeee');

my $color_scheme = {      #  OUTLINE,		FILL
	'transcript'       => [ 'orange',		'red'		],
	'translation'      => [ 'darkgreen',	'green'		],
	'Est2genome_human' => [ 'blue',			'violet'	],
	'Est2genome_mouse' => [ 'blue',			'violet'	],
	'Est2genome_other' => [ 'blue',			'violet'	],
	'vertrna'          => [ 'black',		'#a05000'	],
	# 'Uniprot'          => [ 'cyan',			'darkblue'	],
	'Uniprot'      => [ 'darkgreen',	'green'		],
};

my $type_to_optpairs = { # canvas-dependent stuff
	'line'		=> [ ['-fill','-disabledfill'] ],
	'text'		=> [ ['-fill','-disabledfill'] ],
	'rectangle'	=> [ ['-fill','-disabledfill'], ['-outline','-disabledoutline'] ],
	'polygon'	=> [ ['-fill','-disabledfill'], ['-outline','-disabledoutline'] ],
};

use strict;
use Evi::SortFilterDialog; # window that selects the sorting order

use Evi::LogicalSelection;	# keeps the information about selection and visibility

use Evi::ScaleQuantum;		# a scaler that exaggerates the small differences in lengths
use Evi::ScaleMinexon;		# a scaler that limits the minimum length of an exon
use Evi::ScaleFitwidth;		# a scaler that fits everything into given width

use Tk::ROText;			# for the status line
use MenuCanvasWindow;	# recommended self-resizing window mgr

use Evi::Tictoc;				# a simple stopwatch

use base ('MenuCanvasWindow','Evi::DestroyReporter'); # we want to track the destruction event


sub after_filtering_sorting_callback {
	my ($self, $results) = @_;

	$self->{_evichains_lp} = $results;

	$self->evi_redraw();
}

sub new {
	my $pkg = shift @_;

	my $parentwindow			= shift @_;
	my $title					= shift @_;

		# create the window with widgets
	my $top_window = $parentwindow->Toplevel(-title => $title);
	my $self = $pkg->SUPER::new($top_window,undef,undef,'','HeadedCanvas');

	$self->{_evicoll}			= shift @_;
	$self->{_transcript}		= shift @_;

	$self->{_scale_type}		= shift @_ || 'Evi::ScaleFitwidth';

	$self->{_sortfilterdialog} = Evi::SortFilterDialog->new(
				$top_window,
				"$title| Sort data",
				$self->{_evicoll},
				1, # uniq_p
				$self,
				'after_filtering_sorting_callback'
	);
	$self->{_sortfilterdialog}->current_transcript($self->{_transcript}); # may be changed later

	$self->{_lselection}		= Evi::LogicalSelection->new($self->{_evicoll},$self->{_transcript});

	$self->{_statusline} = $top_window->ROText(-height=>1)->pack(-side => 'bottom');

	my $menu_file = $self->make_menu('File');
	$menu_file->command(
        -label      => 'Save and exit',
        -command    => [ \&exit_callback, ($self, 1, 0) ],
	);
	$menu_file->command(
        -label      => 'Exit without saving',
        -command    => [ \&exit_callback, ($self, 0, 0) ],
	);

	my $menu_data = $self->make_menu('Data');
	$menu_data->command(
        -label      => 'Change ~sorting/filtering order ...',
		-command => [ $self->{_sortfilterdialog} => 'open' ],
    );

	my $menu_view = $self->make_menu('View');
	$menu_view->radiobutton(
		-label	=> '~Proportional view',
		-value	=> 'Evi::ScaleFitwidth',
		-variable => \$self->{_scale_type},
		-command => [ \&evi_redraw, ($self) ],
	);
	$menu_view->radiobutton(
		-label	=> '~Quantum view',
		-value	=> 'Evi::ScaleQuantum',
		-variable => \$self->{_scale_type},
		-command => [ \&evi_redraw, ($self) ],
	);
if(0) {
	$menu_view->radiobutton(
		-label	=> '~MinExon view',
		-value	=> 'Evi::ScaleMinexon',
		-variable => \$self->{_scale_type},
		-command => [ \&evi_redraw, ($self) ],
	);
	$menu_view->radiobutton(
		-label	=> '~Proportional 1:1 view',
		-value	=> 'Evi::ScaleBase',
		-variable => \$self->{_scale_type},
		-command => [ \&evi_redraw, ($self) ],
	);
}

	$self->{_menu_selection} = $self->make_menu('Selection');

	$top_window->protocol('WM_DELETE_WINDOW', [ $self => 'exit_callback', 1, 1 ]);

	# $top_window->bind('<Destroy>', sub { $self->{_sortfilterdialog}=$self=undef; });

	$self->{_sortfilterdialog}->filter_and_sort(1);

	return $self;
}

sub exit_callback {
	my ($self, $save, $interactive) = @_;

	if($save && $self->{_lselection}->any_changes_in_selection()) {
		warn "There were changes in the selection";
		if(!$interactive || ($self->top_window()->messageBox(
								-title => 'Please reply',
								-message => 'Do you want to save the changes?',
								-type => 'YesNo',
								-icon => 'question',
								-default => 'Yes',
						) eq 'Yes')
		) {
			$self->{_lselection}->save_to_transcript();
			print "The list of selected evidence changed.";
			print "The new list of selected evidence is:\n";

			use Data::Dumper;
			print Dumper($self->{_transcript}->transcript_info);
			if (my $ec = $self->ExonCanvas) {
				$ec->save_OtterTranscript_evidence($self->{_transcript});
			}
		} else {
			warn "Refused to save the changes";
		}
	} else {
		warn "No changes in the selection or ignoring them";
	}

	$self->{_sortfilterdialog}->release();
	my $top_window = $self->top_window();
	$self->release();
	warn "closing the EviDisplay window";
	$top_window->destroy();
}

sub ExonCanvas {
    my( $self, $ExonCanvas ) = @_;
    
    if ($ExonCanvas) {
        $self->{'_ExonCanvas'} = $ExonCanvas;
    }
    return $self->{'_ExonCanvas'};
}

sub populate_scale {
	my $self = shift @_;

		# $self->{_scale_type} contains the class name
	$self->{_scale} = $self->{_scale_type}->new();

		# first, collect all transcript's boundaries
	for my $exon (@{ $self->{_transcript}->get_all_Exons() }) {
		$self->{_scale}->add_pair( $exon->start(), $exon->end() );
	}

	if($self->{_transcript}->translation()) { # both ends of the translation
		$self->{_scale}->add_pair(
			$self->{_transcript}->coding_region_start(),
			$self->{_transcript}->coding_region_end()
		);
	}

		# then, collect all the matches' boundaries
	for my $evichain (@{$self->{_evichains_lp}}) {
		for my $af (@{$evichain->afs_lp()}) {
			$self->{_scale}->add_pair( $af->start(), $af->end() );
		}
	}
}

sub evi_redraw {
	my $self = shift @_;

my $tt_redraw = Evi::Tictoc->new("EviDisplay layout");

	$self->populate_scale();

	$self->canvas()->delete('all'); # to make it reentrant

	my $tran_strand = $self->{_transcript}->get_all_Exons()->[0]->strand();

		# show the transcript
	$self->draw_exons(
			$self->canvas()->Subwidget('top_canvas'),
			$self->canvas()->Subwidget('main_canvas'),
			$self->canvas()->Subwidget('topleft_canvas'),
			$self->{_transcript}->get_all_Exons(),
			undef,
			undef,
			-1,
			$self->{_transcript}->transcript_info()->name(),
			$tran_strand,
			[	"Name: ".$self->{_transcript}->transcript_info()->name(),
				"Strand: ".strand2name($tran_strand),
			],
			'transcript',
			$half_delta,
			1
			);

		# show the translation
	if($self->{_transcript}->translation()) {
		$self->draw_exons(
			$self->canvas()->Subwidget('top_canvas'),
			$self->canvas()->Subwidget('main_canvas'),
			$self->canvas()->Subwidget('topleft_canvas'),
			$self->{_transcript}->get_all_Exons(),
			$self->{_transcript}->coding_region_start(),
			$self->{_transcript}->coding_region_end(),
			-1,
			$self->{_transcript}->transcript_info()->name(),
			$tran_strand,
			[	"Name: ".$self->{_transcript}->transcript_info()->name(),
				"Strand: ".strand2name($tran_strand),
			],
			'translation',
			$half_delta-2,
			0
			);
	}

	warn "SC_MIN: ".$self->{_scale}->get_scaled_min()."\n";
	warn "SC_MAX: ".$self->{_scale}->get_scaled_max()."\n";

		# force the canvas to resize just once and speed up the whole process of drawing:
	$self->canvas()->Subwidget('main_canvas')->createLine(
		$self->{_scale}->get_scaled_min(),
		0,
		$self->{_scale}->get_scaled_max(),
		scalar(@{$self->{_evichains_lp}})*$ystep,
		-fill => $self->canvas()->Subwidget('main_canvas')->cget(-bg), # transparent
	);

	for my $screendex (0..@{$self->{_evichains_lp}}-1) {

		my $evichain = $self->{_evichains_lp}[$screendex];
		$self->draw_exons(
			$self->canvas()->Subwidget('main_canvas'),
			$self->canvas()->Subwidget('top_canvas'),
			$self->canvas()->Subwidget('left_canvas'),
			$evichain->afs_lp(),
			undef,
			undef,
			$screendex,
			$evichain->name(),
			$evichain->strand(),
			[
				(map { $_->{_name}.':  '.$_->compute($evichain); }
					@{$self->{_sortfilterdialog}->active_criteria()}),
				'-----------------------',
				(map { $_->{_name}.':  '.$_->compute($evichain); }
					@{$self->{_sortfilterdialog}->remaining_criteria()}),
				"Strand: ".strand2name($evichain->strand()),
			],
			$evichain->analysis(),
			$half_delta,
			1
			);
	}

	$self->canvas()->fit_everything();
	$self->fix_window_min_max_sizes;

	$self->fix_ribbon_widths(
		$self->canvas()->Subwidget('topleft_canvas'),
		$self->canvas()->Subwidget('left_canvas'),
		0,
		5, # make the right edge invisible
	);
	$self->fix_ribbon_widths(
		$self->canvas()->Subwidget('top_canvas'),
		$self->canvas()->Subwidget('main_canvas'),
		5, # make the left edge invisible
		0,
	);

	$self->redraw_selection();

$tt_redraw->done();
}

sub fix_ribbon_widths {
	my ($self,$from_canvas,$to_canvas,$left_delta,$right_delta) = @_;

	my ($left,$y1,$right,$y2) = $from_canvas->cget(-scrollregion);
	$left	-= $left_delta;
	$right	+= $right_delta-1;

	for my $canvas ($to_canvas, $from_canvas) {
		for my $id ($canvas->find('withtag','backribbon')) {
			my @coords = $canvas->coords($id);
			$coords[0]=$left;
			$coords[2]=$right;
			$canvas->coords($id,@coords);
		}
	}
}

sub strand2arrow {
	return ((shift @_) == 1) ? '=>' : '<=';
}

sub strand2name {
	return ((shift @_) == 1) ? 'forward' : 'reverse';
}

sub draw_exons {
	my ($self,$where,$where_alt,$where_text,$exons_lp,$start_at,$end_at,
		$screendex,$name_tag,$chain_strand,$infotext,$scheme,$hd,$draw_stripes) = @_;

	my ($ocolor,$fcolor) = @{$color_scheme->{$scheme}};
	my $stripecolor = $alternating_colors[$screendex % 2];

	my $ribbon_top	= $ystep*$screendex;
	my $ribbon_bot	= $ystep*($screendex+1)-1;
	my $mid_y		= $ystep*($screendex+1/2);

	my $exon_top	= $mid_y - $hd;
	my $exon_bot	= $mid_y + $hd;
	my $intron_top  = $mid_y - $half_delta;
	my $intron_bot  = $mid_y + $half_delta;

	my $chain_tag = "rowindex_$screendex";	# make it unique (i.e. differ from non-unique $name_tag)

	if($draw_stripes) {
			# white-lightgrey background stripes for the chains themselves
		$where->createRectangle(
			$self->{_scale}->get_scaled_min(),
			$ribbon_top,
			$self->{_scale}->get_scaled_max(),
			$ribbon_bot,
			-outline => $stripecolor,
			-fill => $stripecolor,
			-disabledoutline => $current_contour_color,
			-disabledfill => $stripecolor,
			-tags =>	[ $name_tag, $chain_tag, 'backribbon' ],
		);

			# white-lightgrey background stripes for text labels
		$where_text->createRectangle(
			0, # to be substituted later
			$ribbon_top,
			0, # to be substituted later
			$ribbon_bot,
			-outline => $stripecolor,
			-fill => $stripecolor,
			-disabledoutline => $current_contour_color,
			-disabledfill => $stripecolor,
			-tags =>	[ $name_tag, $chain_tag, 'backribbon' ],
		);

		$where_text->createText(0, $mid_y,
			-fill => 'black',
			-disabledfill => $current_contour_color,
			-text =>	$name_tag.' '.strand2arrow($chain_strand),
			-anchor =>	'e',
			-tags =>	[ $chain_tag, $name_tag ],
		);
	}

	my @all_exon_intron_tags = ();

	my ($i_start,$i_from);

		# Transcript's order of exons is natural (head to tail)
		# EviChain's order of exons is ascending, independently of the strand
		#
		# This may mean that we'll have to change the order when making Transcripts from EviChains
		#
	for my $exon (sort {$a->start() <=> $b->start()} @$exons_lp) {

		my $e_start = $exon->start();
		my $e_end   = $exon->end();

		if($start_at) {
			if($e_end<$start_at) { # skip exons to the left
				next;
			} elsif(($e_start<=$start_at) && ($start_at<=$e_end)) { # trim it
				$e_start = $start_at;
			}
		}

		if($end_at) {
			if($end_at<$e_start) { # skip exons to the right
				last;
			} elsif(($e_start<=$end_at) && ($end_at<=$e_end)) { # trim it
				$e_end = $end_at;
			}
		}

		my $from = $self->{_scale}->scale_point($e_start);
		my $to   = $self->{_scale}->scale_point($e_end);
		my $exon_tag = 'exon_'.$e_start.'_'.$e_end; # must be scale-independent

			# draw the preceding intron, if there is one:
		if(defined($i_start)) {
			my $intron_tag = 'intron_'.$i_start.'_'.($e_start-1);
			my $i_mid_x = ($i_from+$from)/2;

				# highlightable background rectangle behind an intron:
			my $rect = $where->createRectangle(
					$i_from,$intron_top,$from,$intron_bot,
				-outline => $stripecolor,
				-fill =>    $stripecolor,
				-disabledoutline => $stripecolor,
				-disabledfill => $highlighting_color,
				-tags =>	[ $intron_tag, $chain_tag, $name_tag ],
			);

			if($scheme ne 'Uniprot') {
				$where->createPolygon(	# the intron itself (angular line pointing upwards)
						$i_from, $mid_y,
						$i_mid_x, $intron_top,
						$from, $mid_y,
						$from, $mid_y,
						$i_mid_x, $intron_top,
						$i_from, $mid_y,
					-outline => $ocolor,
					-fill    => $fcolor,
					-disabledoutline => $current_contour_color,
					-disabledfill    => $highlighting_color,
					-tags =>	[ $intron_tag, $chain_tag, $name_tag ],
				);
			} else {
				$where->createLine(	# the pseudointron (straight horisontal dashed line)
						$i_from, $mid_y,
						$from, $mid_y,
					-fill	=> $ocolor,
					-disabledfill => $current_contour_color,
					-dash	=> [5,3],
					-tags =>	[ $intron_tag, $chain_tag, $name_tag ],
				);
			}

			push @all_exon_intron_tags, $intron_tag;

if($bind_ok) {
			$where->bind($intron_tag,'<ButtonPress-1>',
				[\&highlight_bindcallback, (1, [$where,$where_alt], $intron_tag)] # FIXME: copy to clipboard
											# or substitute by a popup
			);
			$where->bind($intron_tag,'<ButtonRelease-1>',
				[\&highlight_bindcallback, (0, [$where,$where_alt], $intron_tag)] # FIXME: copy to clipboard
			);
}
		}

			# now, draw the exon itself:
		$where->createRectangle($from, $exon_top, $to, $exon_bot,
			-outline => $ocolor,
			-fill =>    $fcolor,
			-disabledoutline => $current_contour_color,
			-disabledfill => $highlighting_color,
			-tags =>	[ $exon_tag, $chain_tag, $name_tag ],
		);
		push @all_exon_intron_tags, $exon_tag;


		# HERE
if(0) {
		$where->createText($from, $exon_top,
			-fill => 'black',
			-text =>	$e_start,
			-anchor =>	'c',
		);
		$where->createText($to, $exon_bot,
			-fill => 'black',
			-text =>	$e_end,
			-anchor =>	'c',
		);
}

if($bind_ok) {
		$where->bind($exon_tag,'<ButtonPress-1>',
			[\&highlight_bindcallback, (1, [$where,$where_alt], $exon_tag)] # FIXME: copy to clipboard
																# or substitute by a popup
		);
		$where->bind($exon_tag,'<ButtonRelease-1>',
			[\&highlight_bindcallback, (0, [$where,$where_alt], $exon_tag)] # FIXME: copy to clipboard
		);
}

			# prepare for the next intron:
		($i_start,$i_from) = ($e_end+1,$to+1);
	}

	# ------------[the "chain-wide" event bindings]----------------------:

	my $tag_expr = join('||',@all_exon_intron_tags);

if($bind_ok) {
		# show *all* similar exons and introns:
	$where_text->bind($chain_tag,'<ButtonPress-1>',
		[\&highlight_bindcallback, (1, [$where,$where_alt], $tag_expr)]
	);
	$where_text->bind($chain_tag,'<ButtonRelease-1>',
		[\&highlight_bindcallback, (0, [$where,$where_alt], $tag_expr)]
	);

	for my $c ($where, $where_text) {
			# highlight the current chain:
		$c->bind($chain_tag,'<Enter>',
			[\&highlight_bindcallback, (1, [$where,$where_text], "$chain_tag||(!backribbon&&$name_tag)")]
		);
		$c->bind($chain_tag,'<Leave>',
			[\&highlight_bindcallback, (0, [$where,$where_text], "$chain_tag||(!backribbon&&$name_tag)")]
		);

			# perform the selection (based on $name_tag)
			#	currently it works on evidence names,
			#	but should be re-written to support full evidence chains (via $chain_tag?)
			#	once they get stored in the database:
		if($screendex>=0) { # do it only for evidences, not for transcript(s)
			$c->bind($name_tag,'<Double-1>',
				[\&toggle_select_by_name_bindcallback, ($self, $name_tag)]
			);
		}
	}

	$self->info_popup($where,$chain_tag,$infotext);
	$self->info_popup($where_text,$chain_tag,$infotext);
}

}

sub info_popup {
	my ($self,$where,$tag,$text) = @_;

	my $info_m = $where->Menu(
		-tearoff => 0,
		-menuitems => [
			map { my $line=$_; [
					Button => $line,
					# -command => [ $self => 'set_statusline', ($line)], # may be needed if called from other class
					-command => [ \&set_statusline, ($self, $line)], # GarbageCollector-ok
			]; } @$text
		]
	);
	$where->bind($tag,'<ButtonPress-3>',
		[ $info_m => 'Popup', (-popover => 'cursor', -popanchor => 'ne') ]
	);
	$where->toplevel()->bind('<ButtonRelease-3>',
		sub { warn "Button 3 released"; }
	);
}

# -------------------------------[status line]-------------------------------------------

sub set_statusline {
		# because of the difference in callback orders
		# IT IS SAFER to parse the args starting from the other end:
	my $line	= pop @_;
	my $self	= pop @_;

	$self->{_statusline}->delete('1.0', 'end');
	$self->{_statusline}->insert('end', $line);
}

sub get_statusline {
	my $self = shift @_;

	return $self->{_statusline}->get(1,'end');
}

# ------------------------------[highlighting]-------------------------------------------

sub highlight_bindcallback { # not a method!
	my ($bound_canvas, $wanted_state, $canvases_lp, $tag_expr) = @_;

print "$tag_expr LENGTH=".length($tag_expr)."\n";

	for my $canvas (@$canvases_lp) {
print "canvas: $canvas\n";

		 my @all_ids = $canvas->find('withtag',$tag_expr);
print "(1) number of IDS: ".scalar(@all_ids)."\n";
		    @all_ids = $canvas->find('withtag',$tag_expr);
print "(2) number of IDS: ".scalar(@all_ids)."\n\n";

		 for my $id (@all_ids) {
		# for my $id ($canvas->find('withtag',$tag_expr)) {
			my $old_state = $canvas->{_highlighted}{$id};

			if( ((not $old_state) and $wanted_state)
			 or ((not $wanted_state) and $old_state)) {
					toggle_highlighting_by_id($canvas,$id);
					$canvas->{_highlighted}{$id} = not $canvas->{_highlighted}{$id};
			}
		}
	}
}

sub toggle_highlighting_by_id { # not a method
	my ($canvas, $id) = @_;

		# flip the outline<->fill colors for all the affected canvas items:
	for my $op ( @{ $type_to_optpairs->{$canvas->type($id)} }) {

			# swap them:
		my $ocol = $canvas->itemcget($id, $op->[0]);
		my $dcol = $canvas->itemcget($id, $op->[1]);

		$canvas->itemconfigure($id, $op->[0] => $dcol);
		$canvas->itemconfigure($id, $op->[1] => $ocol);
	}
}

# ----------------------------------[de/selection]-------------------------------------------

sub deselect_by_name { # NB: sometimes it is a method, sometimes it is not!
		# Because of the difference in callback orders
		# IT IS SAFER to parse the args starting from the other end:
	my $name_tag	= pop @_;
	my $self		= pop @_;

	for my $canvas (@{ $self->canvas()->canvases() }) {
		for my $id ($canvas->find('withtag',"$name_tag&&backribbon")) {
			for my $opt ('-fill','-disabledfill') {
				my $orig_color = $self->{_selected_items}{$name_tag}{$id}{$opt};
				$canvas->itemconfigure($id, $opt => $orig_color);
			}
		}
	}
	$self->{_lselection}->deselect($name_tag);

	my $ms = $self->{_menu_selection}; # unconditionally remove  from the menu
	for my $ind (0..$ms->index('last')) { # if the beginning matches...
		if( $ms->entrycget($ind,-label)=~/^$name_tag/ ) {
			$ms->delete($ind);
		}
	}
}

sub select_by_name { # NB: sometimes it is a method, sometimes it is not!
		# Because of the difference in callback orders
		# IT IS SAFER to parse the args starting from the other end:
	my $name_tag	= pop @_;
	my $self		= pop @_;

	$self->{_lselection}->select($name_tag); # NB: invisible by default

	for my $canvas (@{ $self->canvas()->canvases() }) {
		for my $id ($canvas->find('withtag',"$name_tag&&backribbon")) {
			for my $opt ('-fill','-disabledfill') {
				my $orig_color = $canvas->itemcget($id,$opt);
				$self->{_selected_items}{$name_tag}{$id}{$opt} = $orig_color;
				$canvas->itemconfigure($id, $opt => $selection_color);
			}
			$self->{_lselection}->set_visibility($name_tag, 1); # something was found and visibly selected
		}
	}

	my $is_vis = $self->{_lselection}->is_visible($name_tag);

		# unconditionally add the removal command to the menu:
	my $submenu = $self->{_menu_selection}->cascade(
			-label		=> ($is_vis
								? $name_tag
								: "$name_tag (invisible)"),
			-tearoff	=> 0,
	);
	if($is_vis) {
		$submenu->command(
			-label		=> "ScrollTo",
			-command	=> [\&scroll_to_obj, ($self, $name_tag) ],
		);
	}
	$submenu->command(
		-label		=> "Remove",
		-command	=> [\&deselect_by_name, ($self, $name_tag) ],
	);
}

sub toggle_select_by_name_bindcallback { # not a method!
	my ($bound_canvas, $self, $name_tag) = @_;

	if($self->{_lselection}->is_selected($name_tag)) { # (definitely visible) deselect it:
		$self->deselect_by_name($name_tag);
	} else { # select it:
		$self->select_by_name($name_tag);
	}
}

sub redraw_selection {
	my $self = shift @_;

	$self->{_menu_selection}->delete(0,'last'); # start from the empty menu

	for my $eviname (@{ $self->{_lselection}->get_list() }) {
		$self->select_by_name($eviname); # try to make it visible
		if(not $self->{_lselection}->is_visible($eviname)) {
			warn "$eviname cannot be selected as it is not visible on the EviDisplay\n";
		}
	}
}

sub release { # the Black Spot
	my $self = shift @_;

	for my $k (keys %$self) {
			delete $self->{$k};
	}
}

1;

