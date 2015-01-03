use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME               => 'Map::Tube',
    AUTHOR             => q{Mohammad S Anwar <mohammad.anwar@yahoo.com>},
    VERSION_FROM       => 'lib/Map/Tube.pm',
    ABSTRACT_FROM      => 'lib/Map/Tube.pm',
    LICENSE            => 'artistic_2',
    PL_FILES           => {},
    MIN_PERL_VERSION   => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES   => {
        'Test::More' => 0,
    },
    PREREQ_PM              => {
        'Moo'              => 0,
        'Moo::Role'        => 0,
        'namespace::clean' => 0,
        'Throwable'        => 0,
        'XML::Simple'      => 0,
        'overload'         => 0
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Map-Tube-*' },
    (eval { ExtUtils::MakeMaker->VERSION(6.46) } ? (META_MERGE => {
        'meta-spec' => { version => 2 },
        provides    => {
            'Map::Tube'            => { file => 'lib/Map/Tube.pm'           },
            'Map::Tube::Node'      => { file => 'lib/Map/Tube/Node.pm'      },
            'Map::Tube::Line'      => { file => 'lib/Map/Tube/Line.pm'      },
            'Map::Tube::Table'     => { file => 'lib/Map/Tube/Table.pm'     },
            'Map::Tube::Route'     => { file => 'lib/Map/Tube/Route.pm'     },
            'Map::Tube::Error'     => { file => 'lib/Map/Tube/Error.pm'     },
            'Map::Tube::Exception' => { file => 'lib/Map/Tube/Exception.pm' },
        },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/Manwar/Map-Tube.git',
                web  => 'https://github.com/Manwar/Map-Tube',
            },
        }})
     : ()
    ),
);
