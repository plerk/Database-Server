use strict;
use warnings;
use Test::More tests => 2;
use Test::Moose;
use Database::Server;

subtest normal => sub {
  plan tests => 7;

  my @command = ($^X, -E => 'say "output"; say STDERR "error"');

  my $ret = Database::Server::CommandResult->new(@command);
  
  isa_ok $ret, 'Database::Server::CommandResult';
  does_ok $ret, 'Database::Server::Role::Result';
  
  ok $ret->is_success, 'is_success';
  
  is_deeply $ret->command, [@command], 'command';
  is $ret->out, "output\n", 'out';
  is $ret->err, "error\n", 'err';
  is $ret->exit, 0, 'exit';
  

};

subtest fail => sub {
  plan tests => 4;

  my @command = ($^X, -E => 'exit 2');
  
  my $ret = Database::Server::CommandResult->new(@command);
  
  isa_ok $ret, 'Database::Server::CommandResult';
  does_ok $ret, 'Database::Server::Role::Result';
  
  ok !$ret->is_success, 'is_success';    
  is $ret->exit, 2, 'exit';

};
