#!/usr/bin/perl

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

