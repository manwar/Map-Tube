#!/usr/bin/perl

use 5.006;
use strict; use warnings;
use Test::More;

my $min_ver = 0.17;
eval "use Test::Map::Tube $min_ver tests => 3";
plan skip_all => "Test::Map::Tube $min_ver required." if $@;

use lib 't/';
use SampleMap;

my $map = SampleMap->new;
ok_map($map);
ok_map_functions($map);

my @routes = <DATA>;
ok_map_routes($map, \@routes);

__DATA__
Route 1|A1|A3|A1,A2,A3
