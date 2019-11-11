#!perl -T

use 5.006;
use strict; use warnings FATAL => 'all';
use Test::More;

my $min_ver = '0.87';
eval "use Map::Tube::London $min_ver tests => 1";
plan skip_all => "Map::Tube::London $min_ver required." if $@;

use Map::Tube::London;
my $map = Map::Tube::London->new;
#isa_ok($map, 'Map::Tube::London');

done_testing();
