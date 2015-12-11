use strict;
use warnings;
use 5.020;
use Test::More tests => 1;
use Database::Server;

package
  Database::Server::FooSQL {
  
  use Moose;
  use Carp qw( croak );
  use namespace::autoclean;
  
  with 'Database::Server::Role::Server';

  has _init => (
    is      => 'rw',
    default => 0,
  );

  has _up => (
    is      => 'rw',
    default => 0,
  );
  
  sub create
  {
    my($class) = @_;
    croak "TODO";
  }
  
  sub init
  {
    my($self) = @_;
    croak "already init" if $self->_init;
    $self->_init(1);
  }
  
  sub start
  {
    my($self) = @_;
    croak "must first init" if $self->_init;
    $self->_up(1);
  }
  
  sub stop
  {
    my($self) = @_;
    croak "must first init" if $self->_init;
    $self->_up(0);
  }
  
  sub is_up
  {
    shift->_up;
  }

  sub list_databases {}
  sub create_database {}
  sub drop_database {}
  sub shell {}
  sub interactive_shell {}
  sub dsn {}

}

subtest 'Database::Server::Role::Server#run' => sub {

  plan tests => 3;
  my $server = Database::Server::FooSQL->new;
  
  is $server->run($^X, -E => 'exit 0')->is_success, 1, 'good command';
  is $server->run($^X, -E => 'exit 2', sub { shift })->is_success, '', 'bad command';
  
  eval { $server->run($^X, -E => 'say "out"; say STDERR "error"; exit 2') };
  like $@, qr{'% .*?' failed with exit 2}, 'exception match';
  note "error = $@";

};

