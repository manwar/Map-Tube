package Map::Tube;

$Map::Tube::VERSION   = '2.72';
$Map::Tube::AUTHORITY = 'cpan:MANWAR';

=head1 NAME

Map::Tube - Core library as Role (Moo) to process map data.

=head1 VERSION

Version 2.72

=cut

use 5.006;
use Try::Tiny;
use XML::Simple;
use Data::Dumper;
use Map::Tube::Node;
use Map::Tube::Line;
use Map::Tube::Table;
use Map::Tube::Route;
use Map::Tube::Pluggable;
use Map::Tube::Exception;
use Map::Tube::Error qw(:constants);

use Moo::Role;
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
has _lines        => (is => 'rw');
has tables        => (is => 'rw');
has routes        => (is => 'rw');
has name_to_id    => (is => 'rw');
has _active_lines => (is => 'rw');

sub BUILD {
    my ($self) = @_;

    $self->_init_map;
    $self->_validate_map_data;
}

=head1 METHODS

=head2 get_shortest_routes($from, $to)

Expects 'from' and 'to' station name and returns an object of type L<Map::Tube::Route>.
On error it returns an object of type L<Map::Tube::Exception>.

=cut

sub get_shortest_route {
    my ($self, $from, $to) = @_;

    ($from, $to) =
        $self->_validate_input('get_shortest_route', $from, $to);

    my $_from = $self->get_node_by_id($from);
    my $_to   = $self->get_node_by_id($to);

    $self->_get_shortest_route($from);

    my $nodes = [];
    while (defined($to) && !(_is_same($from, $to))) {
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

Expects 'from' and 'to' station name and returns ref to a list of objects of type
L<Map::Tube::Route>. On error it returns an object of type L<Map::Tube::Exception>.

Be carefull when using against a large map. You may encountered warning as 'deep-recursion'.
It throws the following error when run against London map.

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

=head2 get_node_by_id($node_id)

Returns node object of type L<Map::Tube::Node> for the given node id.

=cut

sub get_node_by_id {
    my ($self, $id) = @_;

    return $self->nodes->{$id};
}

=head2 get_node_by_name($node_name)

Returns node object of type L<Map::Tube::Node> for the given node name.

=cut


sub get_node_by_name {
    my ($self, $name) = @_;

    return unless (defined $name && defined $self->_get_id($name));

    return $self->get_node_by_id($self->_get_id($name));
}

=head2 get_lines()

Returns ref to a list of objects of type L<Map::Tube::Line>.

=cut

sub get_lines {
    my ($self) = @_;

    return $self->lines;
}

=head2 get_stations($line_name)

Returns ref to a list of objects of type L<Map::Tube::Node> for the given line.

=cut

sub get_stations {
    my ($self, $line) = @_;

    my @caller = caller(0);
    @caller = caller(2) if $caller[3] eq '(eval)';

    Map::Tube::Exception->throw({
        method      => __PACKAGE__."::get_stations",
        message     => "ERROR: Missing Line name.",
        status      => ERROR_MISSING_LINE_NAME,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (defined $line);

    Map::Tube::Exception->throw({
        method      => __PACKAGE__."::get_stations",
        message     => "ERROR: Invalid Line name.",
        status      => ERROR_INVALID_LINE_NAME,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (exists $self->_lines->{uc($line)});

    return $self->_lines->{uc($line)}->get_stations;
}

=head2 as_image($line_name)

Returns line image as base64 encoded string. It expects the plugin L<Map::Tube::Plugin::Graph>
to be installed.

=cut

sub as_image {
    my ($self, $line) = @_;

    my @caller = caller(0);
    @caller = caller(2) if $caller[3] eq '(eval)';

    Map::Tube::Exception->throw({
        method      => __PACKAGE__."::as_image",
        message     => "ERROR: Missing Line name.",
        status      => ERROR_MISSING_LINE_NAME,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (defined $line);

    Map::Tube::Exception->throw({
        method      => __PACKAGE__."::as_image",
        message     => "ERROR: Invalid Line name.",
        status      => ERROR_INVALID_LINE_NAME,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (exists $self->_lines->{uc($line)});

    my @plugins = Map::Tube::Pluggable::plugins;
    Map::Tube::Exception->throw({
        method      => __PACKAGE__."::as_image",
        message     => "ERROR: Missing graph plugin Map::Tube::Plugin::Graph.",
        status      => ERROR_MISSING_PLUGIN_GRAPH,
        filename    => $caller[1],
        line_number => $caller[2] }) if (scalar(@plugins) == 0);

    my $graph;
    eval { $graph = $plugins[0]->new; };
    Map::Tube::Exception->throw({
        method      => __PACKAGE__."::as_image",
        message     => "ERROR: Unable to load plugin Map::Tube::Plugin::Graph.",
        status      => ERROR_LOADING_PLUGIN_GRAPH,
        filename    => $caller[1],
        line_number => $caller[2] }) if ($@);

    if (defined $graph && ref($graph) && $graph->isa('Map::Tube::Plugin::Graph')) {
        $graph->tube($self);
        $graph->line($self->_lines->{uc($line)});

        return $graph->as_image;
    }
}

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

    while (defined($from)) {
        my $length = $self->_get_length($from);
        my $f_node = $self->get_node_by_id($from);
        $self->_set_active_lines($f_node);

        if (defined $f_node) {
            my $links = [ split /\,/,$f_node->link ];
            while (scalar(@$links) > 0) {
                my ($success, $link) = $self->_get_next_link($from, $seen, $links);
                $success or ($links = [ grep(!/$link/, @$links) ]) and next;

                if (($self->_get_length($link) == 0) || ($length > ($index + 1))) {
                    $self->_set_length($link, $length + 1);
                    $self->_set_path($link, $from);
                    push @$nodes, $link;
                }
                $seen->{$link} = 1;
                $links = [ grep(!/$link/, @$links) ];
            }
        }

        $index = $length + 1;
        $from  = shift @$nodes;
        $nodes = [ grep(!/$from/, @$nodes) ] if defined $from;
    }
}

sub _get_all_routes {
    my ($self, $visited, $to) = @_;

    my $last  = $visited->[-1];
    my $nodes = $self->get_node_by_id($last)->link;
    foreach my $id (split /\,/, $nodes) {
        next if _is_visited($id, $visited);

        if (_is_same($id, $to)) {
            push @$visited, $id;
            $self->_set_routes($visited);
            pop @$visited;
            last;
        }
    }

    foreach my $id (split /\,/, $nodes) {
        next if (_is_visited($id, $visited) || _is_same($id, $to));

        push @$visited, $id;
        $self->_get_all_routes($visited, $to);
        pop @$visited;
    }

    return $self->{routes};
}

sub _map_node_name {
    my ($self, $name, $id) = @_;

    $self->{name_to_id}->{uc($name)} = $id;
}

sub _validate_input {
    my ($self, $method, $from, $to) = @_;

    my @caller = caller(0);
    @caller = caller(2) if $caller[3] eq '(eval)';

    Map::Tube::Exception->throw({
        method      => __PACKAGE__."::$method",
        message     => "ERROR: Either FROM/TO node is undefined",
        status      => ERROR_MISSING_NODE_NAME,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (defined($from) && defined($to));

    $from = _format($from);
    my $_from = $self->get_node_by_name($from);
    Map::Tube::Exception->throw({
        method      => __PACKAGE__."::$method",
        message     => "ERROR: Received invalid FROM node '$from'",
        status      => ERROR_INVALID_NODE_NAME,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (defined $_from);

    $to = _format($to);
    my $_to = $self->get_node_by_name($to);
    Map::Tube::Exception->throw({
        method      => __PACKAGE__."::$method",
        message     => "ERROR: Received invalid TO node '$to'",
        status      => ERROR_INVALID_NODE_NAME,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (defined $_to);

    return ($_from->id, $_to->id);
}

sub _init_map {
    my ($self) = @_;

    my $_lines = {};
    my $lines  = {};
    my $nodes  = {};
    my $tables = {};
    my $xml    = XMLin($self->xml, KeyAttr => 'stations', ForceArray => 0);
    $self->name($xml->{name});

    foreach my $station (@{$xml->{stations}->{station}}) {
        my $id   = $station->{id};
        my $name = $station->{name};
        die "ERROR: Duplicate station name [$name].\n" if (defined $self->_get_id($name));

        $self->_map_node_name($name, $id);
        $tables->{$id} = Map::Tube::Table->new({ id => $id });

        my $_station_lines = [];
        foreach my $_line (split /\,/,$station->{line}) {
            my $uc_line = uc($_line);
            my $line    = $lines->{$uc_line};
            $line = Map::Tube::Line->new({ name => $_line }) unless defined $line;
            $_lines->{$uc_line} = $line;
            $lines->{$uc_line}  = $line;
            push @$_station_lines, $line;
        }

        $station->{line} = $_station_lines;
        my $node = Map::Tube::Node->new($station);
        $nodes->{$id} = $node;

        foreach (@{$_station_lines}) {
            $_->add_station($node);
        }
    }

    foreach my $_line (@{$xml->{lines}->{line}}) {
        my $line = $_lines->{uc($_line->{name})};
        if (defined $line) {
            $line->id($_line->{id});
            $line->color($_line->{color});
            $_lines->{uc($_line->{name})} = $line;
        }
    }

    $self->lines([ values %$lines ]);
    $self->_lines($_lines);
    $self->nodes($nodes);
    $self->tables($tables);
}

sub _init_table {
    my ($self) = @_;

    foreach my $id (keys %{$self->tables}) {
        $self->tables->{$id}->path(undef);
        $self->tables->{$id}->length(0);
    }

    $self->_active_lines(undef);
}

sub _common_lines {
    my ($array1, $array2) = @_;

    my %element = map { $_ => undef } @{$array1};
    return grep { exists($element{$_}) } @{$array2};
}

sub _get_next_link {
    my ($self, $from, $seen, $links) = @_;

    my $active_lines = $self->_active_lines;
    my @common_lines = _common_lines($active_lines->[0], $active_lines->[1]);
    my $link         = undef;
    foreach my $_link (@$links) {
        return (0,  $_link)
            if ((exists $seen->{$_link}) || ($from eq $_link));

        my $node = $self->get_node_by_id($_link);
        next unless defined $node;

        my @lines  = (split /\,/, $node->line);
        my @common = _common_lines(\@common_lines, \@lines);
        return (1, $_link) if (scalar(@common) > 0);

        $link = $_link;
    }

    return (1, $link);
}

sub _set_active_lines {
    my ($self, $node) = @_;

    my $active_lines = $self->_active_lines;
    my $links        = [ split /\,/, $node->link ];

    if (defined $active_lines) {
        shift @$active_lines;
        push @$active_lines, $links;
    }
    else {
        push @$active_lines, $links;
        push @$active_lines, $links;
    }

    $self->_active_lines($active_lines);
}

sub _validate_map_data {
    my ($self) = @_;

    my $seen  = {};
    my $nodes = $self->nodes;
    foreach my $id (keys %$nodes) {
        my $node = $self->get_node_by_id($id);
        die "ERROR: Node ID can't have ',' character.\n" if ($id =~ /\,/);

        my $link = $node->link;
        foreach (split /\,/,$link) {
            next if (exists $seen->{$_});
            my $_node = $self->get_node_by_id($_);

            die "ERROR: Found invalid node id [$_].\n" unless (defined $_node);
            $seen->{$_} = 1;
        }
    }

    $self->_validate_self_linked_nodes;

    $self->_validate_multi_linked_nodes;

    $self->_validate_multi_lined_nodes;
}

sub _validate_self_linked_nodes {
    my ($self) = @_;

    my $max_link = 0;
    foreach my $id (keys %{$self->nodes}) {
        if (grep { $_ eq $id } (split /\,/, $self->get_node_by_id($id)->link)) {
            $max_link++;
        }

        if ($max_link > 0) {
            die sprintf("ERROR: %s is self linked,", $id);
        }
    }
}

sub _validate_multi_linked_nodes {
    my ($self) = @_;

    foreach my $id (keys %{$self->nodes}) {
        my %links = ();
        foreach my $link (split( /\,/, $self->get_node_by_id($id)->link)) {
            $links{$link}++;
        }

        my $max_link = 1;
        foreach (keys %links) {
            $max_link = $links{$_} if ($max_link < $links{$_});
        }

        if ($max_link > 1) {
            die sprintf("ERROR: %s linked to %s multiple times,",
                        $id, join( ',', grep { $links{$_} > 1 } keys %links));
        }
    }
}

sub _validate_multi_lined_nodes {
    my ($self) = @_;

    foreach my $id (keys %{$self->nodes}) {
        my %lines = ();
        $lines{$_}++ for split( /\,/, $self->get_node_by_id($id)->line);

        my $max_link = 1;
        foreach (keys %lines) {
            $max_link = $lines{$_} if ($max_link < $lines{$_});
        }

        if ($max_link > 1) {
            die sprintf("ERROR: %s has multiple lines %s,",
                        $id, join( ',', grep { $lines{$_} > 1 } keys %lines));
        }
    }
}

sub _set_routes {
    my ($self, $routes) = @_;

    my $_routes = [];
    foreach my $id (@$routes) {
        push @$_routes, $self->get_node_by_id($id);
    }

    my $from  = $_routes->[0];
    my $to    = $_routes->[-1];
    my $route = Map::Tube::Route->new({ from => $from, to => $to, nodes => $_routes });
    push @{$self->{routes}}, $route;
}

sub _get_path {
    my ($self, $id) = @_;

    return $self->tables->{$id}->path;
}

sub _set_path {
    my ($self, $id, $node_id) = @_;

    $self->tables->{$id}->path($node_id);
}

sub _get_length {
    my ($self, $id) = @_;

    return 0 unless defined $self->tables->{$id};
    return $self->tables->{$id}->length;
}

sub _set_length {
    my ($self, $id, $value) = @_;

    $self->tables->{$id}->length($value);
}

sub _get_table {
    my ($self, $id) = @_;

    return $self->tables->{$id};
}

sub _get_id {
    my ($self, $name) = @_;

    return $self->{name_to_id}->{uc($name)};
}

sub _format {
    my ($data) = @_;

    return unless defined $data;

    $data =~ s/\s+/ /g;
    $data =~ s/^\s+//g;
    $data =~ s/\s+$//g;

    return $data;
}

sub _is_same {
    my ($this, $that) = @_;

    return 0 unless (defined($this) && defined($that));

    (_is_number($this) && _is_number($that))
    ?
    (return ($this == $that))
    :
    (uc($this) eq uc($that));
}

sub _is_visited {
    my ($id, $list) = @_;

    foreach (@$list) {
        return 1 if _is_same($_, $id);
    }

    return 0;
}

sub _is_number {
    my ($this) = @_;

    return (defined($this)
            && ($this =~ /^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/));
}

=head1 AUTHOR

Mohammad S Anwar, C<< <mohammad.anwar at yahoo.com> >>

=head1 REPOSITORY

L<https://github.com/Manwar/Map-Tube>

=head1 SEE ALSO

L<Map::Metro>

=head1 CONTRIBUTORS

=over 2

=item * Gisbert W. Selke (map data validation)

=item * Michal Špaček

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

This  program  is  free software; you can redistribute it and/or modify it under
the  terms  of the the Artistic License (2.0). You may obtain a copy of the full
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
