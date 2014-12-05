package Map::Tube;

$Map::Tube::VERSION = '2.33';

=head1 NAME

Map::Tube - Core library as Role (Moo) to process map data.

=head1 VERSION

Version 2.33

=cut

use utf8;
use 5.006;
use XML::Simple;
use Data::Dumper;
use Map::Tube::Node;
use Map::Tube::Table;
use Map::Tube::Route;
use Map::Tube::Exception;
use Map::Tube::Error qw(:constants);

use Moo::Role;
use namespace::clean;

requires 'xml';

=head1 DESCRIPTION

The core module defined as Role (Moo) to process  the map data.  It provides the
the interface to find the shortest route in terms of stoppage between two nodes.
Also you can get all possible routes between two given nodes.

This role has been taken by the following modules:

=over 4

=item L<Map::Tube::London>

=item L<Map::Tube::Tokyo>

=item L<Map::Tube::NYC>

=item L<Map::Tube::Delhi>

=item L<Map::Tube::Barcelona>

=item L<Map::Tube::Prague>

=item L<Map::Tube::Warsaw>

=item L<Map::Tube::Sofia>

=item L<Map::Tube::Berlin>

=back

=cut

has nodes      => (is => 'rw');
has tables     => (is => 'rw');
has routes     => (is => 'rw');
has name_to_id => (is => 'rw');

sub BUILD {
    my ($self) = @_;

    $self->init_map;
    $self->validate_map_data;
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
    while (defined($from) && defined($to) && !(_is_same($from, $to))) {
        push @$nodes, $self->get_node_by_id($to);
        $to = $self->get_path($to);
    }

    push @$nodes, $_from;

    return Map::Tube::Route->new(
        { from  => $_from,
          to    => $_to,
          nodes => [ reverse(@$nodes) ] } );
}

=head2 get_all_routes($from, $to)

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

sub init_map {
    my ($self) = @_;

    my $nodes  = {};
    my $tables = {};
    my $xml    = XMLin($self->xml, KeyAttr => 'stations', ForceArray => 0);

    foreach my $station (@{$xml->{stations}->{station}}) {
        my $node = Map::Tube::Node->new($station);
        my $id   = $node->id;
        my $name = $node->name;
        die "ERROR: Duplicate station name [$name].\n" if (defined $self->get_id($name));

        $self->map_name($name, $id);
        $nodes->{$id}  = $node;
        $tables->{$id} = Map::Tube::Table->new({ id => $id });
    }

    $self->nodes($nodes);
    $self->tables($tables);
}

sub init_table {
    my ($self) = @_;

    foreach my $id (keys %{$self->tables}) {
        $self->tables->{$id}->path(undef);
        $self->tables->{$id}->length(0);
    }
}

sub validate_map_data {
    my ($self) = @_;

    my $seen  = {};
    my $nodes = $self->nodes;
    foreach my $id (keys %$nodes) {
        my $node = $self->get_node_by_id($id);
        die "ERROR: Node ID can't have ',' character.\n"
            if ($id =~ /\,/);

        my $link = $node->link;
        foreach (split /\,/,$link) {
            next if (exists $seen->{$_});
            my $_node = $self->get_node_by_id($_);

            die "ERROR: Found invalid node id [$_].\n"
                unless (defined $_node);
            $seen->{$_} = 1;
        }
    }
}

sub map_name {
    my ($self, $name, $id) = @_;

    $self->{name_to_id}->{uc($name)} = $id;
}

sub get_id {
    my ($self, $name) = @_;

    return $self->{name_to_id}->{uc($name)};
}

sub get_node_by_id {
    my ($self, $id) = @_;

    return $self->nodes->{$id};
}

sub get_node_by_name {
    my ($self, $name) = @_;

    return unless (defined $name && defined $self->get_id($name));

    return $self->get_node_by_id($self->get_id($name));
}

sub set_routes {
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

sub get_path {
    my ($self, $id) = @_;

    return $self->tables->{$id}->path;
}

sub set_path {
    my ($self, $id, $node_id) = @_;

    $self->tables->{$id}->path($node_id);
}

sub get_length {
    my ($self, $id) = @_;

    return 0 unless defined $self->tables->{$id};
    return $self->tables->{$id}->length;
}

sub set_length {
    my ($self, $id, $value) = @_;

    $self->tables->{$id}->length($value);
}

sub get_table {
    my ($self, $id) = @_;

    return $self->tables->{$id};
}

#
#
# PRIVATE METHODS

sub _get_shortest_route {
    my ($self, $from) = @_;

    my $nodes = [];
    my $index = 0;

    $self->init_table;
    $self->set_length($from, $index);
    $self->set_path($from, $from);

    while (defined($from)) {
        my $length = $self->get_length($from);
        my $f_node = $self->get_node_by_id($from);
        if (defined $f_node) {
            foreach my $link (split /\,/, $f_node->link) {
                if (($self->get_length($link) == 0) || ($length > ($index + 1))) {
                    $self->set_length($link, $length + 1);
                    $self->set_path($link, $from);
                    push @$nodes, $link;
                }
            }
        }

        $index = $length + 1;
        $from  = shift @$nodes;
        $nodes = [ grep(!/$from/, @$nodes) ];
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
            $self->set_routes($visited);
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

Copyright 2010 - 2014 Mohammad S Anwar.

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
