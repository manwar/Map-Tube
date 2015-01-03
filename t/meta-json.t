#!/usr/bin/perl

use strict; use warnings;
use Test::More;

eval "use Test::CPAN::Meta::JSON";
plan skip_all => "Test::CPAN::Meta::JSON required for testing MYMETA.json" if $@;

meta_spec_ok('MYMETA.json', undef, @_);

done_testing();
