#!/usr/bin/perl

use 5.006;
use strict; use warnings;
use Test::More;

my $min_ver = 0.17;
eval "use Test::Map::Tube $min_ver tests => 7";
plan skip_all => "Test::Map::Tube $min_ver required." if $@;

use lib 't/';
use SampleMap;

my $map = SampleMap->new;
ok_map($map);
ok_map_functions($map);

my @routes = <DATA>;
ok_map_routes($map, \@routes);

eval { Map::Tube::Line->new({ id => 'A', name => 'A', color => 'xyz' }); };
like($@, qr/isa check for "color" failed/);

eval { Map::Tube::Line->new({ id => 'A', name => 'A', color => 'red' }); };
like($@, qr//);

eval { Map::Tube::Line->new({ id => 'A', name => 'A' }); };
like($@, qr//);

eval { Map::Tube::Line->new({ id => 'A', name => 'A', color => '#AAAAAA' }); };
like($@, qr//);

__DATA__
Route 1|A1|A3|A1,A2,A3
