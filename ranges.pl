#!/usr/bin/perl

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


open F, "</dev/usb/hiddev1";
binmode F;


my $ranges = [
          [
            1000,
            -1000
          ],
          [
            1000,
            -1000
          ],
          [
            1000,
            -1000
          ],
          [
            1000,
            -1000
          ],
          [
            1000,
            -1000
          ],
          [
            1000,
            -1000
          ],
        ];

my $v;
my $c = 0;
while (1) {
    read F, my $buf, 8; # 8 bytes
    my @d = unpack "ssss", $buf;
    push @v, $d[2];
    if (@v==15) {
        my @e;
        for my $i (0..6) {
            my $vi = unpack "s", pack( "WW", $v[$i*2],$v[$i*2+1]);

            if ( $ranges->[$i][0] > $vi ) {
                $ranges->[$i][0] = $vi;
            }
            if ( $ranges->[$i][1] < $vi ) {
                $ranges->[$i][1] = $vi;
            }

            push @e, $vi;
        }
        @v = ();

        if ( not $c++ % 100 ) {
            use Data::Dumper; 
            print Dumper $ranges;
        }
    }
}

close F;

