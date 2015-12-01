use strict;
use warnings;
use 5.020;

package Database::Server {

  # ABSTRACT: Base classes and roles for interacting with database server instances

=head1 METHODS

=head2 generate_port

 Database::Server->generate_port;

Returns an unused TCP port number.

=cut

  sub generate_port
  {
    require IO::Socket::IP;
    IO::Socket::IP->new(Listen => 5, LocalAddr => '127.0.0.1')->sockport;
  }

}

package Database::Server::Role::Server {

  use Moose::Role;
  use namespace::autoclean;
  
  requires 'create';
  requires 'init';
  requires 'start';
  requires 'stop';
  requires 'is_up';

  sub run
  {
    my $error_check = ref $_[-1] eq 'CODE'
      ? pop 
      : sub { my $result = shift; die $result unless $result->is_success; $result };
    my($self, @command) = @_;
    $error_check->(Database::Server::CommandResult->new(@command));
  }
  
  sub restart
  {
    my($self) = @_;
    $self->stop if $self->is_up;
    $self->start;
  }

}

package Database::Server::Role::Result {

  use Moose::Role;
  use overload '""' => sub { shift->as_string };
  use namespace::autoclean;
  
  requires 'is_success';
  requires 'as_string';

}

package Database::Server::Role::ProcessResult {

  use Moose::Role;
  use namespace::autoclean;
  
  with 'Database::Server::Role::Result';

  has out => (
    is  => 'ro',
    isa => 'Str',
  );

  has err => (
    is  => 'ro',
    isa => 'Str',
  );
  
  has exit => (
    is  => 'ro',
    isa => 'Int',
  );
  
  sub is_success
  {
    !shift->exit;
  }
  
  has command => (
    is  => 'ro',
    isa => 'ArrayRef[Str]',
  );

}

package Database::Server::CommandResult {

  use Moose;
  use Capture::Tiny qw( capture );
  use Carp qw( croak );
  use experimental 'postderef';
  use namespace::autoclean;

  with 'Database::Server::Role::ProcessResult';

  sub BUILDARGS
  {
    my $class = shift;
    my %args = ( command => [map { "$_" } @_] );
    
    ($args{out}, $args{err}) = capture { system $args{command}->@* };
    croak "failed to execute @{[ $args{command}->@* ]}: $?" if $? == -1;
    my $signal = $? & 127;
    croak "command @{[ $args{command}->@* ]} killed by signal $signal" if $args{signal};

    $args{exit}   = $args{signal} ? 0 : $? >> 8;
        
    \%args;
  }

  sub as_string
  {
    my($self) = @_;
    my $str = "'% @{[ $self->command->@* ]}' failed with exit @{[ $self->exit ]}";
    $str .= "\n[out]\n" . $self->out if $self->out;
    $str .= "\n[err]\n" . $self->err if $self->err;
    $str;
  }
  
  __PACKAGE__->meta->make_immutable;

}

1;
