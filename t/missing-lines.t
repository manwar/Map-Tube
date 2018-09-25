package MissingLinesMap;

use Moo;
use namespace::autoclean;

has json => (is => 'ro', default => sub { File::Spec->catfile('t', 'missing-lines.json') });
with 'Map::Tube';

package main;

use 5.006;
use strict; use warnings;
use Test::More;

my $min_ver = 0.35;
eval "use Test::Map::Tube $min_ver tests => 1";
plan skip_all => "Test::Map::Tube $min_ver required." if $@;

eval { MissingLinesMap->new };
like($@, qr/XXX/);
