package Map::Tube::Types;

$Map::Tube::Types::VERSION   = '4.09';
$Map::Tube::Types::AUTHORITY = 'cpan:MANWAR';

=head1 NAME

Map::Tube::Types - Attribute type definition for Map::Tube.

=head1 VERSION

Version 4.09

=cut

use v5.14;
use strict; use warnings;

use Type::Library -base, -declare => qw(Color Node NodeMap Nodes Line LineMap Lines Route Routes Table Tables);
use Types::Standard qw(Str InstanceOf ArrayRef Map);
use Type::Utils;
use Map::Tube::Utils qw(is_valid_color);

declare 'Color',
    as Str,
    where   { is_valid_color($_) },
    message { "ERROR: Invalid color name [$_]." };

declare 'Node',
    as InstanceOf['Map::Tube::Node'];

declare 'NodeMap',
    as Map[Str, Node];

declare 'Nodes',
    as ArrayRef[Node];

declare 'Line',
    as InstanceOf['Map::Tube::Line'];

declare 'LineMap',
    as Map[Str, Line];

declare 'Lines',
    as ArrayRef[Line];

declare 'Route',
    as InstanceOf['Map::Tube::Route'];

declare 'Routes',
    as ArrayRef[Route];

declare 'Table',
    as InstanceOf['Map::Tube::Table'];

declare 'Tables',
    as Map[Str, Table];

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY>.

=head1 AUTHOR

Mohammad Sajid Anwar, C<< <mohammad.anwar at yahoo.com> >>

=head1 REPOSITORY

L<https://github.com/manwar/Map-Tube>

=head1 BUGS

Please report any bugs or feature requests through the web interface at L<https://github.com/manwar/Map-Tube/issues>.
I will be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Map::Tube::Types

You can also look for information at:

=over 4

=item * BUG Report

L<https://github.com/manwar/Map-Tube/issues>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Map-Tube>

=item * Search MetaCPAN

L<https://metacpan.org/dist/Map-Tube/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 - 2025 Mohammad Sajid Anwar.

This program  is  free software; you can redistribute it and / or modify it under
the  terms  of the the Artistic License  (2.0). You may obtain a copy of the full
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

1; # End of Map::Tube::Types
