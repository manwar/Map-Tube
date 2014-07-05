use 5.006;
use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Map::Tube',
    license             => 'artistic_2',
    dist_author         => q{Mohammad S Anwar <mohammad.anwar@yahoo.com>},
    dist_version_from   => 'lib/Map/Tube.pm',
    release_status      => 'stable',
    configure_requires  => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'Moo'         => 0,
        'Throwable'   => 0,
        'XML::Simple' => 0,
        'overload'    => 0
    },
    add_to_cleanup     => [ 'Map-Tube-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
