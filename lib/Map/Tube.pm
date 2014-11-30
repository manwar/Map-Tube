package Map::Tube;

$Map::Tube::VERSION = '2.27';

=head1 NAME

Map::Tube - Core library as Role (Moo) to process map data.

=head1 VERSION

Version 2.27

=cut

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

The core module defined as Role (Moo) to process  the map data.  It also provides
the interface to find the shortest route in terms of stoppage between two nodes.

This role has been taken by one of my module L<Map::Tube::London>.

=cut

has map    => (is => 'rw');
has nodes  => (is => 'rw');
has tables => (is => 'rw');
has routes => (is => 'rw');

sub BUILD {
    my ($self) = @_;

    $self->init_map;
    $self->setup_map;
}

sub get_shortest_route {
    my ($self, $from, $to) = @_;

    my @caller = caller(0);
    @caller = caller(2) if $caller[3] eq '(eval)';

    Map::Tube::Exception->throw({
        method      => __PACKAGE__.'::get_shortest_route',
        message     => "ERROR: Either FROM/TO node is undefined",
        status      => ERROR_MISSING_NODE_NAME,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (defined($from) && defined($to));

    $from = _format($from);
    my $_from = $self->get_node_by_name($from);
    Map::Tube::Exception->throw({
        method      => __PACKAGE__.'::get_shortest_route',
        message     => "ERROR: Received invalid FROM node '$from'",
        status      => ERROR_INVALID_NODE_NAME,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (defined $_from);

    $to = _format($to);
    my $_to = $self->get_node_by_name($to);
    Map::Tube::Exception->throw({
        method      => __PACKAGE__.'::get_shortest_route',
        message     => "ERROR: Received invalid TO node '$to'",
        status      => ERROR_INVALID_NODE_NAME,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless (defined $_to);

    $from = $_from->id;
    $to   = $_to->id;
    $self->_get_shortest_route($from);

    my $nodes = [];
    while (defined($from) && defined($to) && !(_is_same($from, $to))) {
        push @$nodes, $self->get_node_by_id($to);
        $to = $self->get_path($to);
    }

    push @$nodes, $self->get_node_by_id($from);

    return Map::Tube::Route->new({ nodes => [ reverse(@$nodes) ] });
}

sub get_node_by_id {
    my ($self, $id) = @_;

    foreach my $name (keys %{$self->nodes}) {
        my $node = $self->get_node_by_name($name);
        return $node if _is_same($node->id, $id);
    }

    return;
}

sub get_node_by_name {
    my ($self, $name) = @_;

    foreach my $_name (keys %{$self->nodes}) {
        return $self->nodes->{$_name} if _is_same($_name, $name);
    }

    return;
}

sub get_routes {
    my ($self, $from, $to) = @_;

    $from = _format($from);
    $to   = _format($to);
    $from = $self->get_node_by_name($from)->id;
    $to   = $self->get_node_by_name($to)->id;

    return $self->_get_routes([$from], $to);
}

sub set_routes {
    my ($self, $routes) = @_;

    my $_routes = [];
    foreach my $id (@$routes) {
        push @$_routes, $self->get_node_by_id($id);
    }

    push @{$self->{routes}}, Map::Tube::Route->new({ nodes => $_routes });
}

sub get_path {
    my ($self, $id) = @_;

    foreach my $table (@{$self->tables}) {
        return $table->path if _is_same($table->id, $id);
    }
}

sub set_path {
    my ($self, $id, $node_id) = @_;

    foreach my $table (@{$self->tables}) {
        return $table->path($node_id) if _is_same($table->id, $id);
    }
}

sub get_length {
    my ($self, $id) = @_;

    foreach my $table (@{$self->tables}) {
        return $table->length if _is_same($table->id, $id);
    }
}

sub set_length {
    my ($self, $id, $value) = @_;

    foreach my $table (@{$self->tables}) {
        return $table->length($value) if _is_same($table->id, $id);
    }
}

sub get_table {
    my ($self, $id) = @_;

    foreach my $table (@{$self->tables}) {
        return $table if _is_same($table->id, $id);
    }
}

sub init_map {
    my ($self) = @_;

    my $map = [];
    my $xml = XMLin($self->xml, KeyAttr => 'stations', ForceArray => 0);

    foreach my $station (@{$xml->{stations}->{station}}) {
        push @$map, Map::Tube::Node->new($station);
    }

    $self->map($map);
}

sub setup_map {
    my ($self) = @_;

    my $nodes  = {};
    my $tables = [];

    foreach my $node (@{$self->map}) {
        $nodes->{$node->name} = $node;
        push @$tables, Map::Tube::Table->new({ id => $node->id });
    }

    $self->nodes($nodes);
    $self->tables($tables);
}

sub init_table {
    my ($self) = @_;

    foreach my $table (@{$self->tables}) {
        $table->path(undef);
        $table->length(0);
    }
}

#
#
# PRIVATE METHODS

sub _get_shortest_route {
    my ($self, $from) = @_;

    my @caller = caller(0);
    Map::Tube::Exception->throw({
        method      => __PACKAGE__.'::_get_shortest_routes',
        message     => "ERROR: Node ID is undefined (FROM)",
        status      => ERROR_MISSING_NODE_ID,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless defined($from);

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

sub _get_routes {
    my ($self, $visited, $to) = @_;

    my $last   = $visited->[-1];
    my @caller = caller(0);

    Map::Tube::Exception->throw({
        method      => __PACKAGE__.'::_get_routes',
        message     => "ERROR: Node ID is undefined (LAST)",
        status      => ERROR_MISSING_NODE_ID,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless defined($last);

    Map::Tube::Exception->throw({
        method      => __PACKAGE__.'::_get_routes',
        message     => "ERROR: Node ID is undefined (TO)",
        status      => ERROR_MISSING_NODE_ID,
        filename    => $caller[1],
        line_number => $caller[2] })
        unless defined($to);

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
        $self->_get_routes($visited, $to);
        pop @$visited;
    }

    return $self->{routes};
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
