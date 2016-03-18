package Bio::Otter::Auth::Server::WebUtils;

use strict;
use warnings;

use Web::Machine;

use parent 'Exporter';
our @EXPORT_OK = qw( web_machine );

sub web_machine {
    my ($resource, $resource_args) = @_;
    my $machine = Web::Machine->new(
        resource      => $resource,
        resource_args => $resource_args,
        );
    return $machine;
}

1;
