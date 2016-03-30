package Bio::Otter::Auth::Server::RelyingParty::Chooser;

use strict;
use warnings;

## no critic(Subroutines::ProhibitCallsToUndeclaredSubs)

use Moo;
extends 'Bio::Otter::Auth::Server::WebApp::Resource';

## use critic(Subroutines::ProhibitCallsToUndeclaredSubs)

sub malformed_request {
    my ($self) = @_;
    return if $self->request->session->{exists};
    # FIXME: No session - should log here
    return 1;
}

sub content_types_provided { return [{'text/html' => 'to_html'}] }

sub to_html {
    my ($self) = @_;

    my $base   = $self->request->base;
    $base =~ s|/$||;
    # FIXME: Should generate list, and URLs, from config
    return << "__EO_HTML__";
<html>
 Log in using:
 <ul>
  <li><a href="$base/external/google">Google</a></li>
  <li><a href="$base/external/orcid" >ORCID</a></li>
 </ul>
</html>
__EO_HTML__
}

1;
