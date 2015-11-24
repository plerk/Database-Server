use strict;
use warnings;
use Test::More tests => 2;
use Database::Server;

do {
  package
    Database::Server::MyResult;

  use Moose;
  with 'Database::Server::Role::Result';

  has ok => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
  );

  sub is_success { shift->ok }
};

ok(Database::Server::MyResult->new(ok => 1)->is_success, 'is_success');
ok(!Database::Server::MyResult->new(ok => 0)->is_success, '!is_success');
