package Map::Tube;

$Map::Tube::VERSION   = '3.02';
$Map::Tube::AUTHORITY = 'cpan:MANWAR';

=head1 NAME

Map::Tube - Core library as Role (Moo) to process map data.

=head1 VERSION

Version 3.02

=cut

use 5.006;
use XML::Twig;
use Data::Dumper;
use Map::Tube::Node;
use Map::Tube::Line;
use Map::Tube::Table;
use Map::Tube::Route;
use Map::Tube::Pluggable;
use Map::Tube::Exception::FoundMultiLinedStation;
use Map::Tube::Exception::FoundMultiLinkedStation;
use Map::Tube::Exception::InvalidStationId;
use Map::Tube::Exception::FoundSelfLinkedStation;
use Map::Tube::Exception::InvalidStationId;
use Map::Tube::Exception::DuplicateStationId;
use Map::Tube::Exception::DuplicateStationName;
use Map::Tube::Exception::MissingStationName;
use Map::Tube::Exception::InvalidStationName;
use Map::Tube::Exception::MissingLineName;
use Map::Tube::Exception::InvalidLineName;
use Map::Tube::Exception::MissingStationId;
use Map::Tube::Utils qw(is_same trim common_lines);

use Moo::Role;
use Role::Tiny qw();
use namespace::clean;

requires 'xml';

=encoding utf8

=head1 DESCRIPTION

The core module defined as Role (Moo) to process  the map data.  It provides the
the interface to find the shortest route in terms of stoppage between two nodes.
Also you can get all possible routes between two given nodes.

This role has been taken by the following modules (and many more):

=over 2

=item * L<Map::Tube::London>

=item * L<Map::Tube::Tokyo>

=item * L<Map::Tube::NYC>

=item * L<Map::Tube::Delhi>

=item * L<Map::Tube::Barcelona>

=item * L<Map::Tube::Prague>

=item * L<Map::Tube::Warsaw>

=item * L<Map::Tube::Sofia>

=item * L<Map::Tube::Berlin>

=back

=cut

has name          => (is => 'rw');
has nodes         => (is => 'rw');
has lines         => (is => 'rw');
has tables        => (is => 'rw');
has routes        => (is => 'rw');
has name_to_id    => (is => 'rw');
has plugins       => (is => 'rw');

has _active_links => (is => 'rw');
has _other_links  => (is => 'rw');
has _lines        => (is => 'rw');

sub BUILD {
    my ($self) = @_;

    $self->_init_map;
    $self->_load_plugins;
}

=head1 SYNOPSIS

=head2 Common Usage

    use strict; use warnings;
    use Map::Tube::London;

    my $tube = Map::Tube::London->new;
    print $tube->get_shortest_route('Baker Street', 'Euston Square'), "\n";

You should expect the result like below:

    Baker Street (Circle, Hammersmith & City, Bakerloo, Metropolitan, Jubilee), Great Portland Street (Circle, Hammersmith & City, Metropolitan), Euston Square (Circle, Hammersmith & City, Metropolitan)

=head2 Special Usage

    use strict; use warnings;
    use Map::Tube::London;

    my $tube = Map::Tube::London->new;
    print $tube->get_shortest_route('Baker Street', 'Euston Square')->preferred, "\n";

You should now expect the result like below:

    Baker Street (Circle, Hammersmith & City, Metropolitan), Great Portland Street (Circle, Hammersmith & City, Metropolitan), Euston Square (Circle, Hammersmith & City, Metropolitan)

=head1 METHODS

=head2 get_shortest_routes($from, $to)

It expects C<$from> and C<$to> station name, required param. It returns an object
of type L<Map::Tube::Route>. On error it throws exception of type L<Map::Tube::Exception>.

=cut

sub get_shortest_route {
    my ($self, $from, $to) = @_;

    ($from, $to) =
        $self->_validate_input('get_shortest_route', $from, $to);

    my $_from = $self->get_node_by_id($from);
    my $_to   = $self->get_node_by_id($to);

    $self->_get_shortest_route($from);

    my $nodes = [];
    while (defined($to) && !(is_same($from, $to))) {
        push @$nodes, $self->get_node_by_id($to);
        $to = $self->_get_path($to);
    }

    push @$nodes, $_from;

    return Map::Tube::Route->new(
        { from  => $_from,
          to    => $_to,
          nodes => [ reverse(@$nodes) ] } );
}

=head2 get_all_routes($from, $to) *** EXPERIMENTAL ***

It expects C<$from> and C<$to> station name, required param. It  returns ref to a
list of objects of type L<Map::Tube::Route>. On error it throws exception of type
L<Map::Tube::Exception>.

Be carefull when using against a large map. You  may encounter warning similar to
as shown below when run against London map.

Deep recursion on subroutine "Map::Tube::_get_all_routes"

However for comparatively smaller map, like below,it is happy to give all routes.

      A(1)  ----  B(2)
     /              \
    C(3)  --------  F(6) --- G(7) ---- H(8)
     \              /
      D(4)  ----  E(5)

=cut

sub get_all_routes {
    my ($self, $from, $to) = @_;

    ($from, $to) =
        $self->_validate_input('get_all_routes', $from, $to);

    return $self->_get_all_routes([ $from ], $to);
}

=head2 get_name()

Returns map name.

=head2 get_node_by_id($node_id)

Returns an object of type L<Map::Tube::Node>.

=cut

sub get_node_by_id {
    my ($self, $id) = @_;

    my @caller = caller(0);
    @caller    = caller(2) if $caller[3] eq '(eval)';
    Map::Tube::Exception::MissingStationId->throw({
        method      => __PACKAGE__."::get_node_by_id",
        message     => "ERROR: Missing station id.",
        filename    => $caller[1],
        line_number => $caller[2] }) unless defined $id;

    return $self->{nodes}->{$id};
}

=head2 get_node_by_name($node_name)

Returns a list of object(s) of type L<Map::Tube::Node> matching node name C<$node_name>.

=cut

sub get_node_by_name {
    my ($self, $name) = @_;

    return unless defined $name;

    my @nodes = $self->_get_node_id($name);
    return unless scalar(@nodes);

    my $nodes = [];
    foreach (@nodes) {
        push @$nodes, $self->get_node_by_id($_);
    }

    return unless scalar(@$nodes);

    if (wantarray) {
        return @{$nodes};
    }
    else {
        return $nodes->[0];
    }
}

=head2 get_line_by_id($line_id)

Returns an object of type L<Map::Tube::Line>.

=cut

sub get_line_by_id {
    my ($self, $id) = @_;

    return unless defined $id;

    foreach my $name (keys %{$self->{_lines}}) {
        return $self->{_lines}->{$name}
            if ($id == $self->{_lines}->{$name}->id);
    }

    return;
}

=head2 get_line_by_name($line_name)

Returns an object of type L<Map::Tube::Line>.

=cut

sub get_line_by_name {
    my ($self, $name) = @_;

    return unless defined $name;
    return unless exists $self->{_lines}->{uc($name)};

    return $self->{_lines}->{uc($name)};
}

=head2 get_lines()

Returns ref to a list of objects of type L<Map::Tube::Line>.

=cut

sub get_lines {
    my ($self) = @_;

    my $lines = [];
    if (defined $self->{_other_links} && scalar(keys %{$self->{_other_links}})) {
        foreach (@{$self->{lines}}) {
            push @$lines, $_
                unless (exists $self->{_other_links}->{uc($_->name)});
        }
    }
    else {
        $lines = $self->{lines};
    }

    return $lines;
}

=head2 get_stations($line_name)

Returns ref to a list of objects of type L<Map::Tube::Node>.

=cut

sub get_stations {
    my ($self, $line) = @_;

    my @caller  = caller(0);
    @caller     = caller(2) if $caller[3] eq '(eval)';
    my $uc_line = uc($line);

    Map::Tube::Exception::MissingLineName->throw({
        method      => __PACKAGE__."::get_stations",
        message     => "ERROR: Missing Line name.",
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (defined $line);

    Map::Tube::Exception::InvalidLineName->throw({
        method      => __PACKAGE__."::get_stations",
        message     => "ERROR: Invalid Line name.",
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (exists $self->{_lines}->{$uc_line});

    return $self->{_lines}->{$uc_line}->{stations};
}

=head1 PLUGINS

=head2 * L<Map::Tube::Plugin::Graph>

The L<Map::Tube::Plugin::Graph> plugin add the support to generate the entire map
or map for a particular line as base64 encoded string (png image).

Please refer to the L<documentation|Map::Tube::Plugin::Graph> for more details.

=head2 * L<Map::Tube::Plugin::Formatter>

The L<Map::Tube::Plugin::Formatter> plugin adds the  support to format the object
supported by the plugin.

Please refer to the L<documentation|Map::Tube::Plugin::Formatter> for more info.

=head2 * L<Map::Tube::Plugin::FuzzyFind>

Gisbert W. Selke, built the add-on for L<Map::Tube> to find stations and lines by
name, possibly partly or inexactly specified. The module is a Moo role which gets
plugged into the Map::Tube::* family automatically once it is installed.

Please refer to the L<documentation|Map::Tube::Plugin::FuzzyFind> for more info.

=head1 MAP DATA VALIDATION

The package L<Test::Map::Tube> can easily be used to validate raw map data.Anyone
building a new map using L<Map::Tube> is advised to have a unit test as a part of
their distribution.Just like in L<Map::Tube::London> package,there is a unit test
something like below:

    use strict; use warnings;
    use Test::More;
    use Map::Tube::London;

    eval "use Test::Map::Tube";
    plan skip_all => "Test::Map::Tube required" if $@;

    ok_map(Map::Tube::London->new);

=cut

#
#
# PRIVATE METHODS

sub _get_shortest_route {
    my ($self, $from) = @_;

    my $nodes = [];
    my $index = 0;
    my $seen  = {};

    $self->_init_table;
    $self->_set_length($from, $index);
    $self->_set_path($from, $from);

    my $all_nodes = $self->{nodes};
    while (defined($from)) {
        my $length = $self->_get_length($from);
        my $f_node = $all_nodes->{$from};
        $self->_set_active_links($f_node);

        if (defined $f_node) {
            my $links = [ split /\,/, $f_node->{link} ];
            while (scalar(@$links) > 0) {
                my ($success, $link) = $self->_get_next_link($from, $seen, $links);
                $success or ($links = [ grep(!/\b$link\b/, @$links) ]) and next;

                if (($self->_get_length($link) == 0) || ($length > ($index + 1))) {
                    $self->_set_length($link, $length + 1);
                    $self->_set_path($link, $from);
                    push @$nodes, $link;
                }

                $seen->{$link} = 1;
                $links = [ grep(!/\b$link\b/, @$links) ];
            }
        }

        $index = $length + 1;
        $from  = shift @$nodes;
        $nodes = [ grep(!/\b$from\b/, @$nodes) ] if defined $from;
    }
}

sub _get_all_routes {
    my ($self, $visited, $to) = @_;

    my $last  = $visited->[-1];
    my $nodes = $self->get_node_by_id($last)->link;
    foreach my $id (split /\,/, $nodes) {
        next if _is_visited($id, $visited);

        if (is_same($id, $to)) {
            push @$visited, $id;
            $self->_set_routes($visited);
            pop @$visited;
            last;
        }
    }

    foreach my $id (split /\,/, $nodes) {
        next if (_is_visited($id, $visited) || is_same($id, $to));

        push @$visited, $id;
        $self->_get_all_routes($visited, $to);
        pop @$visited;
    }

    return $self->{routes};
}

sub _map_node_name {
    my ($self, $name, $id) = @_;

    push @{$self->{name_to_id}->{uc($name)}}, $id;
}

sub _validate_input {
    my ($self, $method, $from, $to) = @_;

    my @caller = caller(0);
    @caller = caller(2) if $caller[3] eq '(eval)';

    Map::Tube::Exception::MissingStationName->throw({
        method      => __PACKAGE__."::$method",
        message     => "ERROR: Either FROM/TO node is undefined",
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (defined($from) && defined($to));

    $from = trim($from);
    my $_from = $self->get_node_by_name($from);
    Map::Tube::Exception::InvalidStationName->throw({
        method      => __PACKAGE__."::$method",
        message     => "ERROR: Received invalid FROM node '$from'",
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (defined $_from);

    $to = trim($to);
    my $_to = $self->get_node_by_name($to);
    Map::Tube::Exception::InvalidStationName->throw({
        method      => __PACKAGE__."::$method",
        message     => "ERROR: Received invalid TO node '$to'",
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (defined $_to);

    return ($_from->{id}, $_to->{id});
}

sub _init_map {
    my ($self) = @_;

    my $_lines = {};
    my $lines  = {};
    my $nodes  = {};
    my $tables = {};
    my $_other_links = {};
    my $_seen_nodes  = {};
    my $xml = XML::Twig->new->parsefile($self->xml)->simplify(keyattr => 'stations', forcearray => 0);
    $self->{name} = $xml->{name};

    my @caller = caller(0);
    @caller = caller(2) if $caller[3] eq '(eval)';

    my $name_to_id = $self->{name_to_id};
    foreach my $station (@{$xml->{stations}->{station}}) {
        my $id = $station->{id};

        Map::Tube::Exception::DuplicateStationId->throw({
            method      => __PACKAGE__."::_init_map",
            message     => "ERROR: Duplicate station id [$id].",
            filename    => $caller[1],
            line_number => $caller[2] }) if (exists $_seen_nodes->{$id});

        $_seen_nodes->{$id} = 1;
        my $name = $station->{name};

        Map::Tube::Exception::DuplicateStationName->throw({
            method      => __PACKAGE__."::_init_map",
            message     => "ERROR: Duplicate station name [$name].",
            filename    => $caller[1],
            line_number => $caller[2] }) if (defined $name_to_id->{uc($name)});

        $self->_map_node_name($name, $id);
        $tables->{$id} = Map::Tube::Table->new({ id => $id });

        my $_station_lines = [];
        foreach my $_line (split /\,/, $station->{line}) {
            my $uc_line = uc($_line);
            my $line    = $lines->{$uc_line};
            $line = Map::Tube::Line->new({ name => $_line }) unless defined $line;
            $_lines->{$uc_line} = $line;
            $lines->{$uc_line}  = $line;
            push @$_station_lines, $line;
        }

        if (exists $station->{other_link} && defined $station->{other_link}) {
            my @link_nodes = ();
            foreach my $_entry (split /\,/, $station->{other_link}) {
                my ($_link_type, $_nodes) = split /\:/, $_entry, 2;
                my $uc_link_type = uc($_link_type);
                my $line = $lines->{$uc_link_type};
                $line = Map::Tube::Line->new({ name => $_link_type }) unless defined $line;
                $_lines->{$uc_link_type} = $line;
                $lines->{$uc_link_type}  = $line;
                $_other_links->{$uc_link_type} = 1;

                push @$_station_lines, $line;
                push @link_nodes, (split /\|/, $_nodes);
            }

            $station->{link} .= "," . join(",", @link_nodes);
        }

        $station->{line} = $_station_lines;
        my $node = Map::Tube::Node->new($station);
        $nodes->{$id} = $node;

        foreach (@{$_station_lines}) {
            push @{$_->{stations}}, $node;
        }
    }

    my @lines;
    if (exists $xml->{lines} && exists $xml->{lines}->{line}) {
        @lines = (ref $xml->{lines}->{line} eq 'HASH')
            ? ($xml->{lines}->{line})
            : @{$xml->{lines}->{line}};
    }

    foreach my $_line (@lines) {
        my $uc_line = uc($_line->{name});
        my $line    = $_lines->{$uc_line};
        if (defined $line) {
            $line->{id}         = $_line->{id};
            $line->{color}      = $_line->{color};
            $_lines->{$uc_line} = $line;
        }
    }

    $self->lines([ values %$lines ]);
    $self->_lines($_lines);
    $self->_other_links($_other_links);
    $self->nodes($nodes);
    $self->tables($tables);
}

sub _init_table {
    my ($self) = @_;

    foreach my $id (keys %{$self->{tables}}) {
        $self->{tables}->{$id}->{path}   = undef;
        $self->{tables}->{$id}->{length} = 0;
    }

    $self->{_active_links} = undef;
}

sub _load_plugins {
    my ($self) = @_;

    $self->{plugins} = [ Map::Tube::Pluggable::plugins ];
    foreach (@{$self->plugins}) {
        Role::Tiny->apply_roles_to_object($self, $_);
    }
}

sub _get_next_link {
    my ($self, $from, $seen, $links) = @_;

    my $nodes        = $self->{nodes};
    my $active_links = $self->{_active_links};
    my @common_lines = common_lines($active_links->[0], $active_links->[1]);
    my $link         = undef;

    foreach my $_link (@$links) {
        return (0,  $_link) if ((exists $seen->{$_link}) || ($from eq $_link));

        my $node = $nodes->{$_link};
        next unless defined $node;

        my @lines = ();
        foreach (@{$node->{line}}) { push @lines, $_->{name}; }

        my @common = common_lines(\@common_lines, \@lines);
        return (1, $_link) if (scalar(@common) > 0);

        $link = $_link;
    }

    return (1, $link);
}

sub _set_active_links {
    my ($self, $node) = @_;

    my $active_links = $self->{_active_links};
    my $links        = [ split /\,/, $node->{link} ];

    if (defined $active_links) {
        shift @$active_links;
        push @$active_links, $links;
    }
    else {
        push @$active_links, $links;
        push @$active_links, $links;
    }

    $self->{_active_links} = $active_links;
}

sub _validate_map_data {
    my ($self) = @_;

    my @caller = caller(0);
    @caller    = caller(2) if $caller[3] eq '(eval)';
    my $nodes  = $self->{nodes};
    my $seen   = {};

    foreach my $id (keys %$nodes) {

        Map::Tube::Exception::InvalidStationId->throw({
            method      => __PACKAGE__."::_validate_map_data",
            message     => "ERROR: Node ID can't have ',' character.",
            filename    => $caller[1],
            line_number => $caller[2] }) if ($id =~ /\,/);

        my $node = $nodes->{$id};

        $self->_validate_nodes(\@caller, $nodes, $node, $seen);
        $self->_validate_self_linked_nodes(\@caller, $node, $id);
        $self->_validate_multi_linked_nodes(\@caller, $node, $id);
        $self->_validate_multi_lined_nodes(\@caller, $node, $id);
    }
}

sub _validate_nodes {
    my ($self, $caller, $nodes, $node, $seen) = @_;

    foreach (split /\,/, $node->{link}) {
        next if (exists $seen->{$_});
        my $_node = $nodes->{$_};

        Map::Tube::Exception::InvalidStationId->throw({
            method      => __PACKAGE__."::_validate_map_data",
            message     => "ERROR: Found invalid node id [$_].",
            filename    => $caller->[1],
            line_number => $caller->[2] }) unless (defined $_node);

        $seen->{$_} = 1;
    }
}

sub _validate_self_linked_nodes {
    my ($self, $caller, $node, $id) = @_;

    if (grep { $_ eq $id } (split /\,/, $node->{link})) {
        Map::Tube::Exception::FoundSelfLinkedStation->throw({
            method      => __PACKAGE__."::_validate_map_data",
            message     => sprintf("ERROR: %s is self linked,", $id),
            filename    => $caller->[1],
            line_number => $caller->[2] });
    }
}

sub _validate_multi_linked_nodes {
    my ($self, $caller, $node, $id) = @_;

    my %links    = ();
    my $max_link = 1;

    foreach my $link (split( /\,/, $node->{link})) {
        $links{$link}++;
    }

    foreach (keys %links) {
        $max_link = $links{$_} if ($max_link < $links{$_});
    }

    if ($max_link > 1) {
        my $message = sprintf("ERROR: %s linked to %s multiple times,",
                              $id, join( ',', grep { $links{$_} > 1 } keys %links));

        Map::Tube::Exception::FoundMultiLinkedStation->throw({
            method      => __PACKAGE__."::_validate_map_data",
            message     => $message,
            filename    => $caller->[1],
            line_number => $caller->[2] });
    }
}

sub _validate_multi_lined_nodes {
    my ($self, $caller, $node, $id) = @_;

    my %lines = ();
    foreach (@{$node->{line}}) { $lines{$_->{name}}++; }

    my $max_link = 1;
    foreach (keys %lines) {
        $max_link = $lines{$_} if ($max_link < $lines{$_});
    }

    if ($max_link > 1) {
        my $message = sprintf("ERROR: %s has multiple lines %s,",
                              $id, join( ',', grep { $lines{$_} > 1 } keys %lines));

        Map::Tube::Exception::FoundMultiLinedStation->throw({
            method      => __PACKAGE__."::_validate_map_data",
            message     => $message,
            filename    => $caller->[1],
            line_number => $caller->[2] });
    }
}

sub _set_routes {
    my ($self, $routes) = @_;

    my $_routes = [];
    my $nodes   = $self->{nodes};
    foreach my $id (@$routes) {
        push @$_routes, $nodes->{$id};
    }

    my $from  = $_routes->[0];
    my $to    = $_routes->[-1];
    my $route = Map::Tube::Route->new({ from => $from, to => $to, nodes => $_routes });
    push @{$self->{routes}}, $route;
}

sub _get_path {
    my ($self, $id) = @_;

    return $self->{tables}->{$id}->{path};
}

sub _set_path {
    my ($self, $id, $node_id) = @_;

    $self->{tables}->{$id}->{path} = $node_id;
}

sub _get_length {
    my ($self, $id) = @_;

    return 0 unless defined $self->{tables}->{$id};
    return $self->{tables}->{$id}->{length};
}

sub _set_length {
    my ($self, $id, $value) = @_;

    $self->{tables}->{$id}->{length} = $value;
}

sub _get_table {
    my ($self, $id) = @_;

    return $self->{tables}->{$id};
}

sub _get_node_id {
    my ($self, $name) = @_;

    my $nodes = $self->{name_to_id}->{uc($name)};
    return unless defined $nodes;

    if (wantarray) {
        return @{$nodes};
    }
    else {
        return $nodes->[0];
    }
}

sub _is_visited {
    my ($id, $list) = @_;

    foreach (@$list) {
        return 1 if is_same($_, $id);
    }

    return 0;
}

=head1 AUTHOR

Mohammad S Anwar, C<< <mohammad.anwar at yahoo.com> >>

=head1 REPOSITORY

L<https://github.com/Manwar/Map-Tube>

=head1 SEE ALSO

L<Map::Metro>

=head1 CONTRIBUTORS

=over 2

=item * Gisbert W. Selke, C<< <gws at cpan.org> >>

=item * Michal Špaček, C<< <skim at cpan.org> >>

=back

=head1 BUGS

Please report any bugs or feature requests to C<bug-map-tube at rt.cpan.org>,  or
through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Map-Tube>.
I will  be notified and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Map::Tube

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Map-Tube>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Map-Tube>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Map-Tube>

=item * Search CPAN

L<http://search.cpan.org/dist/Map-Tube/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 - 2015 Mohammad S Anwar.

This program  is  free software; you can redistribute it and / or modify it under
the  terms  of the the Artistic License (2.0). You may obtain a  copy of the full
license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any  use,  modification, and distribution of the Standard or Modified Versions is
governed by this Artistic License.By using, modifying or distributing the Package,
you accept this license. Do not use, modify, or distribute the Package, if you do
not accept this license.

If your Modified Version has been derived from a Modified Version made by someone
other than you,you are nevertheless required to ensure that your Modified Version
 complies with the requirements of this license.

This  license  does  not grant you the right to use any trademark,  service mark,
tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge patent license
to make,  have made, use,  offer to sell, sell, import and otherwise transfer the
Package with respect to any patent claims licensable by the Copyright Holder that
are  necessarily  infringed  by  the  Package. If you institute patent litigation
(including  a  cross-claim  or  counterclaim) against any party alleging that the
Package constitutes direct or contributory patent infringement,then this Artistic
License to you shall terminate on the date that such litigation is filed.

Disclaimer  of  Warranty:  THE  PACKAGE  IS  PROVIDED BY THE COPYRIGHT HOLDER AND
CONTRIBUTORS  "AS IS'  AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES. THE IMPLIED
WARRANTIES    OF   MERCHANTABILITY,   FITNESS   FOR   A   PARTICULAR  PURPOSE, OR
NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY YOUR LOCAL LAW. UNLESS
REQUIRED BY LAW, NO COPYRIGHT HOLDER OR CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL,  OR CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE
OF THE PACKAGE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1; # End of Map::Tube
