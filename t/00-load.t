#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 3;

BEGIN {
    use_ok( 'Map::Tube' ) || print "Bail out!\n";
    use_ok( 'Map::Tube::Errors' ) || print "Bail out!\n";
    use_ok( 'Map::Tube::Exception' ) || print "Bail out!\n";
}

diag( "Testing Map::Tube $Map::Tube::VERSION, Perl $], $^X" );
