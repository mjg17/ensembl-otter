
### GenomeCanvas

package GenomeCanvas;

use strict;
use Carp;
use Tk;
use GenomeCanvas::MainWindow;
use GenomeCanvas::Band;
use GenomeCanvas::BandSet;
use GenomeCanvas::Drawable;
use GenomeCanvas::State;

use vars '@ISA';
@ISA = ('GenomeCanvas::State');

sub new {
    my( $pkg, $tk, $width, $height ) = @_;
    
    $width  ||= 500;
    $height ||= 200;
    
    unless ($tk) {
        confess "Error usage: GenomeCanvas->new(<Tk::Widget object>)";
    }
    
    my $gc = bless {}, $pkg;
    $gc->new_State;
    
    # Create and store the canvas object
    my $scrolled = $tk->Scrolled('Canvas',
        -highlightthickness => 1,
        -background         => 'white',
        -scrollbars         => 'se',
        -width              => $width,
        -height             => $height,
        );
    $scrolled->pack(
        -side => 'top',
        -fill => 'both',
        -expand => 1,
        );
        
    my $canvas = $scrolled->Subwidget('canvas');
    $gc->canvas($canvas);
    $gc->window_width($width);
    $gc->window_height($height);
    return $gc;
}

sub window_width {
    my( $gc, $n ) = @_;
    
    if ($n) {
        confess "Can't reset window_width"
            if $gc->{'_window_width'};
        $gc->{'_window_width'} = $n;
    }
    return $gc->{'_window_width'};
}

sub window_height {
    my( $gc, $n ) = @_;
    
    if ($n) {
        confess "Can't reset window_height"
            if $gc->{'_window_height'};
        $gc->{'_window_height'} = $n;
    }
    return $gc->{'_window_height'};
}

sub band_padding {
    my( $gc, $pixels ) = @_;
    
    if ($pixels) {
        $gc->{'_band_padding'} = $pixels;
    }
    return $gc->{'_band_padding'} || 20;
}

sub render {
    my( $gc ) = @_;
    
    my $canvas = $gc->canvas;
    my ($x_origin, $y_origin) = (0,0);
    foreach my $set ($gc->band_sets) {
        $set->render;
        
        # Expand the frame down the y axis by the
        # amount given by band_padding
        my @bbox = $gc->frame;
        $bbox[3] += $gc->band_padding;
        $gc->frame(@bbox);
    }
}

sub new_BandSet {
    my( $gc ) = @_;
    
    my $band_set = GenomeCanvas::BandSet->new;
    push( @{$gc->{'_band_sets'}}, $band_set );
    $band_set->add_State($gc->state);
    return $band_set;
}

sub band_sets {
    my( $gc ) = @_;
    
    return @{$gc->{'_band_sets'}};
}

sub fix_window_min_max_sizes {
    my( $gc ) = @_;
    
    my $canvas = $gc->canvas;
    
    my @bbox = $canvas->bbox('all');
    $gc->expand_bbox(\@bbox, 5);
    $canvas->configure(
        -scrollregion => [@bbox],
        );

    my $mw = $canvas->toplevel;
    $mw->update;
    $mw->minsize($mw->width, $mw->height);
    $mw->maxsize(
        $bbox[2] - $bbox[0] + $mw->width  - $gc->window_width,
        $bbox[3] - $bbox[1] + $mw->height - $gc->window_height,
        );
    $mw->resizable(1,1);
}

1;

__END__

=head1 NAME - GenomeCanvas

=head1 DESCRIPTION

GenomeCanvas is a container object for a
Tk::Canvas object, and one or many
GenomeCanvas::BandSet objects.

Each GenomeCanvas::BandSet object contains a
Bio::EnsEMBL::Virtual::Contig object, and one or
many GenomeCanvas::Band objects.

Each GenomeCanvas::Band contains an array
containing one or many GenomeCanvas::Drawable
objects, in the order in which they are drawn
onto the canvas.  To render each Drawable object,
the Band object passes the appropriate data as
arguments to the draw() method on the Drawable.

=head1 AUTHOR

James Gilbert B<email> jgrg@sanger.ac.uk

