package Test::Bio::Otter::Auth::Server::RelyingParty::Profile::Google;

use Test::Class::Most
    parent     => 'Test::Bio::Otter::Auth::Server::WebMachine';

sub build_attributes { return; } # none

sub setup       { return; }  # don't let OtterTest::Class do its OO stuff
sub constructor { return; }  # --"--

1;

