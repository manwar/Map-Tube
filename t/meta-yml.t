#!/usr/bin/perl

use strict; use warnings;
use Test::More;

eval "use Test::CPAN::Meta";
plan skip_all => "Test::CPAN::Meta required for testing MYMETA.yml" if $@;

meta_spec_ok('MYMETA.yml', undef, @_);

done_testing();
