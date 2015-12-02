use strict;
use warnings;
use Test::More tests => 2;
use File::Temp qw( tempdir );
use Database::Server;
use Path::Class qw( file dir );

my $dir = dir( tempdir( CLEANUP => 1 ) );

$dir->subdir('DBD')->mkpath(0,0700);
$dir->file('DBD', 'Foo.pm')->spew('package DBD::Foo; 1');
$dir->file('DBD', 'Bar.pm')->spew('package DBD::Foo; 1');
unshift @INC, "$dir";

my $dbi = Database::Server::DBI->new(
  possible_drivers => [qw( Foo Bar Baz )],
);

isa_ok $dbi, 'Database::Server::DBI';

is_deeply $dbi->available_drivers, [qw( Foo Bar )], 'dbi.available_drivers';
