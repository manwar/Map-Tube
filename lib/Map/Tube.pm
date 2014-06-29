package Map::Tube;

$Map::Tube::VERSION = '0.01';

use 5.006;
use XML::Simple;
use Data::Dumper;
use Map::Tube::Node;

use Moo;
use namespace::clean;

=head1 NAME

Map::Tube - The great new Map::Tube!

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

=head1 METHODS

=cut

has xml => (is => 'ro');
has map => (is => 'rw');

sub BUILD {
    my ($self) = @_;

    my $xml = XMLin($self->xml, KeyAttr => 'stations', ForceArray => 0);
    my $map = {};

    foreach my $station (@{$xml->{stations}->{station}}) {
        $map->{$station->{id}} = Map::Tube::Node->new(
            link   => [split /\,/, $station->{link}],
            line   => [split /\,/, $station->{line}],
            name   => $station->{name},
            path   => undef,
            length => undef);
    }

    $self->map($map);
}

sub get_shortest_route {
    my ($self, $from, $to) = @_;

    my $_from = $self->_get_node_code($from);
    my $_to   = $self->_get_node_code($to);
    $self->_process($_from, $_to);

    my @route = ();
    while (defined($_from) && defined($_to) && !(_is_same($_from, $_to))) {
	push @route, $self->map->{$_to};
	$_to = $self->map->{$_to}->path;
    }

    push @route, $self->{map}->{$_from};
    return join(", ", reverse(@route));
}

sub _process {
    my ($self, $from, $to) = @_;

    my $queues = [];
    my $index  = 0;

    $self->_set_path($from, $from);
    $self->_set_length($from, $index);

    while (defined($from)) {
        my $links = $self->_get_links($from);
	foreach my $link (@{$links}) {
            my $link_length = $self->_get_length($link);
            my $from_length = $self->_get_length($from);
            if (!defined($link_length)
                || ($from_length > ($index + 1))) {
		$self->_set_length($link, ($from_length + 1));
                $self->_set_path($link, $from);
		push @$queues, $link;
	    }
	}
	$index  = $self->_get_length($from) + 1;
	$from   = $self->_get_next_node($from, $queues);
	$queues = [ grep(!/$from/, @$queues) ];
    }
}

sub _get_next_node {
    my ($self, $from, $list) = @_;

    return unless (defined($list) && scalar(@{$list}));

    my $from_routes = $self->_get_routes($from);
    foreach my $route (@$from_routes) {
        foreach my $code (@{$list}) {
            my $next_routes = $self->_get_routes($code);
            return $code if grep(/$route/, @$next_routes);
        }
    }

    return shift(@{$list});
}


sub _get_routes {
    my ($self, $station) = @_;

    return $self->map->{$station}->line;
}

sub _get_name {
    my ($self, $station) = @_;

    return $self->map->{$station}->name;
}

sub _get_links {
    my ($self, $station) = @_;

    return $self->map->{$station}->link;
}

sub _get_path {
    my ($self, $station) = @_;

    return $self->map->{$station}->path;
}

sub _set_path {
    my ($self, $station, $path) = @_;

    $self->map->{$station}->path($path);
}

sub _get_length {
    my ($self, $station) = @_;

    return $self->map->{$station}->length;
}

sub _set_length {
    my ($self, $station, $length) = @_;

    $self->map->{$station}->length($length);
}

sub _get_node_code {
    my ($self, $name) = @_;

    foreach my $code (keys %{$self->map}) {
        return $code if _is_same($self->map->{$code}->name, $name);
    }

    return;
}

sub _is_same {
    my ($this, $that) = @_;

    return 0 unless (defined($this) && defined($that));

    if (_is_number($this) && _is_number($that)) {
        return ($this == $that);
    }
    else {
        return (uc($this) eq uc($that));
    }
}

sub _is_number {
    my ($this) = @_;

    return (defined($this)
            && ($this =~ /^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/));
}

=head1 AUTHOR

Mohammad S Anwar, C<< <mohammad.anwar at yahoo.com> >>

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

Copyright 2014 Mohammad S Anwar.

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
