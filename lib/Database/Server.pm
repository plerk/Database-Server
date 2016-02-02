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
  
  requires 'list_databases';
  requires 'create_database';
  requires 'drop_database';
  requires 'interactive_shell';
  requires 'shell';
  requires 'dsn';

  sub run
  {
    my $error_check = ref $_[-1] eq 'CODE'
      ? pop 
      : sub { my $result = shift; $result->is_success ? $result : die $result };
    my($self, @command) = @_;
    $error_check->(Database::Server::CommandResult->new(@command));
  }
  
  sub runnb
  {
    my $error_check = ref $_[-1] eq 'CODE'
      ? pop 
      : sub { my $result = shift; $result->is_success ? $result : die $result };
    my($self, @command) = @_;
    $error_check->(Database::Server::CommandResult::NoBackground->new(@command, sub { $self->is_up }));    
  }
  
  sub good
  {
    Database::Server::SimpleResult->new;
  }
  
  sub fail
  {
    my($message) = @_;
    Database::Server::SimpleResult->new( message => $message, ok => 0 );
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

package Database::Server::SimpleResult {

  use Moose;
  use namespace::autoclean;
  
  with 'Database::Server::Role::Result';
  
  has message => ( is => 'ro', isa => 'Str', default => '' );
  has ok      => ( is => 'ro', isa => 'Str', default => 1  );
  
  sub is_success { shift->ok }
  sub as_string  { shift->message }

}

package Database::Server::Role::ProcessResult {

  use Moose::Role;
  use experimental 'postderef';
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

  sub as_string
  {
    my($self) = @_;
    my $str = "'% @{[ $self->command->@* ]}' failed with exit @{[ $self->exit ]}";
    $str .= "\n[out]\n" . $self->out if $self->out;
    $str .= "\n[err]\n" . $self->err if $self->err;
    $str;
  }
  
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

  __PACKAGE__->meta->make_immutable;

}

package Database::Server::CommandResult::NoBackground {

  use Moose;
  use File::Temp qw( tempdir );
  use Path::Class qw( dir );
  use experimental 'postderef';
  use POSIX qw( :sys_wait_h );
  use Carp qw( croak );
  use namespace::autoclean;
  
  with 'Database::Server::Role::ProcessResult';

  sub BUILDARGS
  {
    my $class = shift;
    my $cb = ref $_[-1] eq 'CODE' ? pop : sub { 0 };
    my %args = ( command => [map { "$_" } @_] );

    my $dir = dir( tempdir( CLEANUP => 0 ) );
    
    my $pid = fork;
    
    if($pid == 0)
    {
      open(STDIN,  '<', '/dev/null');
      open(STDOUT, '>', $dir->file('stdout'));
      open(STDERR, '>', $dir->file('stderr'));

      my $pid2 = fork;
      if($pid2 == 0)
      {
        exit 2 unless exec $args{command}->@*;
      }
      
      my $exit = 0;

      for(1..10) {
        last if waitpid($pid2, WNOHANG) && ($exit = $?);
        sleep 1;
      }
      
      require JSON::PP;
      eval {
        $dir->file('status.json')->spew(
          JSON::PP::encode_json({
            signal => $exit & 128,
            exit   => $exit >> 8,
          }),
        )
      };

      exit;
    }
    
    for(1..20)
    {
      if($cb->())
      {
        $dir->rmtree(0,1);
        $args{exit} = 0;
        $args{out}  = '';
        $args{err}  = '';
        return \%args;
      }
      if(waitpid($pid, WNOHANG))
      {
        require JSON::PP;
        my $status = JSON::PP::decode_json($dir->file('status.json')->slurp);
        $args{exit} = $status->{exit};
        $args{out}  = $dir->file('stdout')->slurp;
        $args{err}  = $dir->file('stderr')->slurp;
        $dir->rmtree(0,1);
        croak "command @{[ $args{command}->@* ]} killed by signal @{[ $status->{signal} ]}" if $status->{signal};
        return \%args;
      }
      sleep 1;
    }
    
    $dir->rmtree(0,1);
    croak "command did not seem to either fail or succeed: @{[ $args{command}->@* ]}";
    
  }
  
  __PACKAGE__->meta->make_immutable
}

1;
