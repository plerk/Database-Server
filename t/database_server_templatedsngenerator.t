use strict;
use warnings;
use Test::More tests => 4;
use File::Temp qw( tempdir );
use Database::Server;
use Path::Class qw( file dir );

my $dir = dir( tempdir( CLEANUP => 1 ) );

$dir->subdir('DBD')->mkpath(0,0700);
$dir->file('DBD', 'Foo.pm')->spew('package DBD::Foo; 1');
$dir->file('DBD', 'Bar.pm')->spew('package DBD::Foo; 1');
unshift @INC, "$dir";

my $dbi = Database::Server::TemplateDSNGenerator->new(
  templates => {
    Foo => 'dbi:Foo:database={ $dbname };server={ $server };port={ $port }',
    Bar => 'dbi:Bar:database={ $dbname };server={ $server };port={ $port }',
    Baz => 'dbi:Baz:database={ $dbname };server={ $server };port={ $port }',
  },
  possible_drivers => [qw( Foo Bar Baz )],
);

isa_ok $dbi, 'Database::Server::TemplateDSNGenerator';

is_deeply $dbi->available_drivers, [qw( Foo Bar )], 'dbi.available_drivers';

is
  $dbi->dsn('Baz', { dbname => 'mydatabase', server => 'myserver', port => 2299 }), 
  'dbi:Baz:database=mydatabase;server=myserver;port=2299',
  'dsn for Baz';

is
  $dbi->dsn(undef, { dbname => 'mydatabase', server => 'myserver', port => 2299 }), 
  'dbi:Foo:database=mydatabase;server=myserver;port=2299',
  'dsn for default';
