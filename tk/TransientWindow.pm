
### TransientWindow

package TransientWindow;

use strict;
use Carp;

sub new{
    my ($cls, $tk, $title) = @_;
    unless($tk){
        confess "need a Tk";
    }
    my $self = bless {}, ref($cls) || $cls;

    $self->title($title);
    my $window   = $tk->Toplevel(-title => $title) || print STDOUT "didn't return window?";
    $window->transient($tk);
    $self->window($window);
    $self->hide_me();

    return $self;
}
sub initialise{
    my ($self) = @_;
    my $window = $self->window();
    $window->protocol('WM_DELETE_WINDOW', $self->hide_me_ref() );
    $window->bind('<Destroy>' , sub { $self = undef }  );
}
sub draw{
    my ($self) = @_;
    $self->show_me();
}
sub hide_me_ref{
    my $self = shift;
    my $ref  = $self->{'_hide_the_window'};
    unless($ref){
        my $window = $self->window();
        $self->{'_hide_the_window'} = $ref = sub{ $window->withdraw(); };
    }
    return $ref;
}
sub hide_me{
    my ($self) = @_;
    $self->hide_me_ref->();
}
sub show_me_ref{
    my ($self) = @_;
    my $ref = $self->{'_show_the_window'};
    unless($ref){
        my $win = $self->window();
        $self->{'_show_the_window'} = $ref = sub{ 
            $win->deiconify;
            $win->raise;
            $win->focus;
        };
    }
    return $ref;
}
sub show_me{
    my $self = shift;
    $self->show_me_ref->();
}

sub window{
    my ($self, $win) = @_;
    if($win){
        $self->{'_window'} = $win;
    }
    return $self->{'_window'};    
}
sub title{
    my ($self, $title) = @_;
    $self->{'_win_title'} = $title if $title;
    return $self->{'_win_title'} || __PACKAGE__;
}

sub text_variable_ref{
    my ($self, $named, $default, $initialise) = @_;
    return undef unless $named;
    $default ||= '';
    if($initialise){
        $self->{'_text_variable_refs'}->{$named} = $default;
    }
    return \$self->{'_text_variable_refs'}->{$named} || \$default;
}
sub action{
    my ($self, $named, $callback, $stack) = @_;
    unless($named){
        warn "usage: $self->action('registeredName', [(CODE_REF)])\n";
        return sub { warn "usage: $self->action('registeredName', [(CODE_REF)])\n" };
    }
    if(ref($callback) && ref($callback) eq 'CODE'){
        $self->{'_actions'}->{$named} = $callback;
    }
    return $self->{'_actions'}->{$named} || sub{  warn "No callback registered for action '$named'\n"; };
}

sub DESTROY{
    my $self = shift;
    my $t = $self->title();
    $self->{'_actions'}            = undef;
    $self->{'_text_variable_refs'} = undef;
    warn "Destroying $self named '$t'";
}
1;

__END__

=head1 NAME - TransientWindow

=head1 AUTHOR

Roy Storey,,,, B<email> rds@sanger.ac.uk

