package Map::Tube;

$Map::Tube::VERSION = '0.01';

use 5.006;
use XML::Simple;
use Data::Dumper;
use Time::HiRes qw(time);
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

has xml   => (is => 'ro');
has nodes => (is => 'rw');
has ucase => (is => 'rw');
has links => (is => 'rw');
has lines => (is => 'rw');
has table => (is => 'rw');

sub BUILD {
    my ($self) = @_;

    my $xml   = XMLin($self->xml, KeyAttr => 'stations', ForceArray => 0);
    my $nodes = {};
    my $links = {};
    my $lines = {};
    my $table = {};
    my $ucase = {};

    foreach my $station (@{$xml->{stations}->{station}}) {
        my $_id    = $station->{id};
        my $_name  = $station->{name};
        my $_links = $station->{link};
        my $_lines = $station->{line};

        $nodes->{$_name}     = $_id;
        $ucase->{uc($_name)} = $_id;

        foreach my $line (split /\,/,$_lines) {
            $lines->{$_id}->{$line} = 1;
        }

        foreach my $link (split /\,/,$_links) {
            push @{$links->{$_id}}, $link;
        }

        $table->{$_id}->{path}   = undef;
        $table->{$_id}->{length} = undef;
    }

    $self->nodes($nodes);
    $self->ucase($ucase);
    $self->links($links);
    $self->lines($lines);
    $self->table($table);
}

sub get_shortest_route {
    my ($self, $from, $to) = @_;

    my $start = Time::HiRes::time;

    croak("ERROR: Either FROM/TO node is undefined.\n")
        unless (defined($from) && defined($to));

    $from =~ s/\s+/ /g;
    $from =~ s/^\s+//g;
    $from =~ s/\s+$//g;

    $to   =~ s/\s+/ /g;
    $to   =~ s/^\s+//g;
    $to   =~ s/\s+$//g;

    croak("ERROR: Received invalid FROM node $from.\n")
        unless exists $self->ucase->{uc($from)};
    croak("ERROR: Received invalid TO node $to.\n")
        unless exists $self->ucase->{uc($to)};

    $from = $self->ucase->{uc($from)};
    $to   = $self->nodes->{$to};

    $self->_process($from);

    my @routes = ();
    my $table  = $self->table;
    while (defined($from) && defined($to) && !(_is_same($from, $to))) {
        push @routes, $self->_get_name($to);
        $to = $table->{$to}->{path};
    }

    push @routes, $self->_get_name($from);

    my $end = Time::HiRes::time;
    print {*STDOUT} sprintf("Time taken %02f second(s).\n", ($end-$start));

    return join(", ", reverse(@routes));
}

sub _init_table {
    my ($self) = @_;

    my $table = $self->table;
    foreach my $id (keys %{$self->links}) {
        $table->{$id}->{path}   = undef;
        $table->{$id}->{length} = undef;
    }

    $self->table($table);
}

sub _process {
    my ($self, $from) = @_;

    my @queue = ();
    my $index = 0;

    $self->_init_table;

    my $table = $self->table;
    my $links = $self->links;

    $table->{$from}->{length} = $index;
    $table->{$from}->{path}   = $from;

    while (defined($from)) {
	foreach my $link (@{$links->{$from}}) {
            if (!defined($table->{$link}->{length})
                || ($table->{$from}->{length} > ($index+1))) {

                $table->{$link}->{length} = $table->{$from}->{length}+1;
                $table->{$link}->{path}   = $from;
                push @queue, $link;
            }
        }

        $index = $table->{$from}->{length}+1;
        $from  = $self->_get_next_node($from, \@queue);

        @queue = grep(!/$from/, @queue);
    }

    $self->table($table);
}

sub _get_next_node {
    my ($self, $from, $list) = @_;

    return unless (defined($list) && scalar(@{$list}));

    return shift(@{$list});

    #my @current_lines = $self->_get_lines($from);
    #foreach my $line (@current_lines) {
    #    foreach my $id (@{$list}) {
    #        my @next_lines = $self->_get_lines($id);
    #        return $id if grep(/$line/,@next_lines);
    #    }
    #}

    return shift(@{$list});
}

sub _get_lines {
    my ($self, $station) = @_;

    my $lines = $self->lines();
    my @lines = keys(%{$lines->{$station}});

    return @lines;
}

sub _get_name {
    my ($self, $station) = @_;

    croak("ERROR: Code is not defined.\n")
        unless defined($station);
    croak("ERROR: Invalid node code '$station'.\n")
        unless exists $self->links->{$station};

    foreach (keys %{$self->nodes}) {
        return $_ if _is_same($self->nodes->{$_}, $station);
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
