#!/usr/bin/env perl

use v5.14;
use strict;
use warnings;
use lib 't/';
use File::Spec;
use Sample;
use Test::Map::Tube tests => 1;

my $routes = [ "Route 1|Station 1|Station 3|Station 1,Station 2,Station 3" ];

my $map = Sample->new( xml => File::Spec->catfile('t', 'map-casetest.xml') );
ok_map_routes( $map, $routes );
