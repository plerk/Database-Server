use strict;
use warnings;
use Test::More tests => 1;
use Database::Server;

subtest failure => sub {

  plan tests => 3;

  my $ret = Database::Server::CommandResult::NoBackground->new($^X, -E => 'say STDERR "some error"; say STDOUT "some output"; exit 3');
  
  is $ret->exit, 3, 'exit = 3';
  like $ret->out, qr{some output}, 'output';
  like $ret->err, qr{some error}, 'error';

};
