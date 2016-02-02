use strict;
use warnings;
use Test::More tests => 1;
use Database::Server;

subtest 'generate_port' => sub {

  my $port = Database::Server->generate_port;

  like $port, qr{^[0-9]+$}, "port: @{[ $port ]}";

};
