package Test::Bio::Otter::Auth::Server;

use Test::Class::Most
    parent      => 'OtterTest::Class',
    is_abstract => 1;

use Test::Otter;

BEGIN {
    $ENV{OTTER_WEB_STREAM} = 'TEST';
}

{
    my $prev_ASC;

    sub _set_ASC : Test(startup) {
        $prev_ASC = $ENV{ANACODE_SERVER_CONFIG};
        $ENV{ANACODE_SERVER_CONFIG} = Test::Otter->proj_rel('t/etc/server-config');
    }

    sub _restore_ASC : Test(shutdown) {
        $ENV{ANACODE_SERVER_CONFIG} = $prev_ASC;
    }
}

1;
