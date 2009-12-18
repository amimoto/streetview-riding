#!/usr/bin/perl

use strict;
use threads;
use threads::shared;
use JSON;
use HTTP::Daemon;
use HTTP::Status;
use Time::HiRes qw/ time /;
use constant{
        PI => 3.14156
    };
use vars qw/ $CFG $SHARED @PACE_TICS /;

$CFG = {
    paths => {
        templates => 'templates',
    },
    hmd => {
        dev_path => '/dev/usb/hiddev0',
        ranges => [
          [ -1012, 996 ],
          [ -1013, 995 ],
          [ -1013, 994 ],
          [ -169, 670 ],
          [ -75, 888 ],
          [ -352, 523 ]
        ],
        zero => [146.24597, 7.33200, -14.08501]
    },
    pace => {
        tty_path       => '/dev/ttyUSB0',
        wheel_diameter => 26 * 0.0254, # 0.0254 = conversion to meters
        avg_over       => 5, # 5 seconds
    },
};

main();

sub main {
# --------------------------------------------------
# Just here to give a quick block view of the overalll
# structure of the code. A sequence of inits and
# the main webserver sits on the update loop
#
    init();

# Create the thread that will watch the hmd's movement
    if ( -f $CFG->{hmd}{dev_path} ) {
        threads->create('hmd');
    }

# Create the thread that keeps track of how fast the 
# bike tire is spinning
    threads->create('pace');

# Main loop
    webserver();
}

sub init {
# --------------------------------------------------
    $SHARED = {};
    share($SHARED);
    my $init_shared = {
        yaw        => 0,
        roll       => 0,
        pitch      => 0,
        distance   => 0,
        zero_yaw   => $CFG->{hmd}{zero}[0],
        zero_roll  => $CFG->{hmd}{zero}[1],
        zero_pitch => $CFG->{hmd}{zero}[2],
    };
    @$SHARED{keys %$init_shared} = values %$init_shared;
    share(@PACE_TICS);
};

sub hmd {
# --------------------------------------------------
# This will connect to the Vuzix vr920 and simply
# read data from the hiddevice setup by linux
# Not sure how it'll work for other people but
# there are some other implementations that I would of 
# used if it weren't for the difficulty to get them
# working on my system. Mostly, it was that usbhid
# just kept grabbing the device from under the nose
# of ther other implementations. So, I made my own
# using usbhid... if you can't win...
# 
# I owe a lot to Jürgen Löb who implemented one of the
# previously mentioned implementations in quite simple
# C code:
#
# http://www.mygnu.de/index.php/2009/03/vr920-headtracking-driver-for-linux/
#
    open my $fh, "<".$CFG->{hmd}{dev_path};
    binmode $fh;

    my @v;
    my $c = 0;
    my @e_old;
    my $ranges = $CFG->{hmd}{ranges};

# We loop indefinitely. Wheee!
    while (1) {
        read $fh, my $buf, 8; # 8 bytes
        my @d = unpack "ssss", $buf;
        push @v, $d[2];

# Once we have 15 bytes of data (masquerading as words), we can 
# assemble them into some useful datastring
        if (@v==15) {
            shift @v; shift @v; pop @v;
            my @e;

# Create the 6 values that will represent acceleration and magnetic pull from
# the different axes
            for my $i (0..5) {
                my $vi = unpack "s", pack( "WW", $v[$i*2],$v[$i*2+1]);

# Normalize
                my $min   = $ranges->[$i][0];
                my $max   = $ranges->[$i][1];
                my $delta = $max-$min;
                $vi = ($vi - $min - $delta/2)/($delta*2);

                push @e, $vi;
            }

# We want to smooth movements down due to things jumping
# around a whole lot
            for my $i (0..$#e) {
                $e[$i] = ( $e_old[$i]*39 + $e[$i] ) / 40;
            }

            calc_orientation(@e);
            @e_old = @e;
            @v = ();

# If for some reason the pitch goes above 50, we'll just reset 
# the connection.
            $SHARED->{pitch} < -50 and do {
warn "RESETTING!\n";
                close $fh;
                open $fh, "<$CFG->{hmd}{dev_path}";
                binmode $fh;
            };
        }
    }

    close $fh;
}

sub pace {
# --------------------------------------------------
# The arduino will send a tick whenever the magnet
# passes the reed switch sensor. We'll need to calibrate
# the system to the circumfrence of the week and assume
# that every tick is a full rotation. Then it's quite easy
# to determine how far we've gone (and how fast)
#
    open my $fh, "<".$CFG->{pace}{tty_path};
    while ( my $l = <$fh> ) {
        $l =~ s/\n|\r//g;
        next unless $l =~ /1/;
        my $now_tics = time;
        push @PACE_TICS, $now_tics;
        my $filter_tics = $now_tics - $CFG->{pace}{avg_over};
        @PACE_TICS = grep {$_ < $filter_tics} @PACE_TICS;
        $SHARED->{distance} += $CFG->{pace}{wheel_diameter} * PI;
    }
    close $fh;
}

sub calc_orientation {
# --------------------------------------------------
# Takes the set of accel and magnetometer readings
# and converts it into a useful set of numbers that
# represent pitch and yaw
#
    my ( $acc_x, $acc_z, $acc_y, $mag_x, $mag_z, $mag_y ) = @_;

    my $PI = 3.14156;
    my $Kd = 180/$PI;
    my $K  = 180/$PI;
    my $acc_roll  = atan2($acc_x,sqrt($acc_y**2 + $acc_z**2))*$Kd;
    my $acc_pitch = atan2($acc_y,sqrt($acc_x**2 + $acc_z**2))*$Kd;

    my $xh = $mag_x*cos((-$acc_roll)/$K)
            + $mag_y*sin(-$acc_roll/$K)*sin($acc_pitch/$K)
            - $mag_z*sin(-$acc_roll/$K)*cos($acc_pitch/$K);
    my $yh = $mag_y*cos($acc_pitch/$K)
            + $mag_z*sin($acc_pitch/$K);

# Zero values(for me): 146.24597, 7.33200, -14.08501
    my $yaw   = 360 - yaw_normalize( $SHARED->{zero_yaw} - atan2($xh,$yh)*$Kd );
    my $roll  = $acc_roll          - $SHARED->{zero_roll};
    my $pitch = $acc_pitch         - $SHARED->{zero_pitch};

    $SHARED->{yaw}   = $yaw;
    $SHARED->{roll}  = $roll;
    $SHARED->{pitch} = -$pitch;
}

sub webserver {
# --------------------------------------------------
    my $d = HTTP::Daemon->new(LocalAddr => 'localhost') || die;
    print "Please contact me at: <URL:", $d->url, ">\n";
    while (my $c = $d->accept) {
        RUN_REQUESTS: while (my $r = $c->get_request) {
#            warn "Requested: ".$r->url."\n";
            HANDLE: {

# Okay, we have an incoming request. What do we want to do with the
# request?
                my $fpath = $r->url->path || '/basic.html';

# Particular paths bring about particular functions... this one 
# will report back the current orientation of the HMD so that the user
# can "look around" the space.
                if ( $fpath eq '/request_update.json' ) {
                    $c->send_response(json_response($SHARED));
                    next RUN_REQUESTS;
                }

# User hit reload. Need to reset the values to original
                elsif ( $fpath eq '/reset_run.json' ) {
                    $SHARED->{distance}   = 0;
                    $c->send_response(json_response($SHARED));
                    next RUN_REQUESTS;
                }

# Incase we want to reset the POV to normal. This is good for when we move
# to a different location
                elsif ( $fpath eq '/zero_pov.json' ) {
                    $SHARED->{zero_yaw}   = $SHARED->{yaw}   + $SHARED->{zero_yaw};
                    $SHARED->{zero_roll}  = $SHARED->{roll}  + $SHARED->{zero_roll};
                    $SHARED->{zero_pitch} = $SHARED->{pitch} - $SHARED->{zero_pitch};
#                    warn "Zero'd: $SHARED->{zero_yaw}, $SHARED->{zero_roll}, $SHARED->{zero_pitch}\n";
                    $c->send_response(json_response($SHARED));
                    next RUN_REQUESTS;
                }

# If we can't find a special function we'll see if there is a template
# tile that matches the request
                $fpath eq '/' and $fpath = '/basic.html';
                my $cfpath = "$CFG->{paths}{templates}$fpath";
                last HANDLE unless -f $cfpath;

                $c->send_file_response($cfpath);
                next RUN_REQUESTS;
            };

            $c->send_error(RC_FORBIDDEN)
        }
        $c->close;
        undef($c);
    }
}

sub json_response {
# --------------------------------------------------
# Just craft the HTTP::Response object required 
# for responses
#
    my ( $data ) = @_;

    my $json_buf = to_json($data);
    my $r = HTTP::Response->new(200);
    $r->header('Content-type','application/json');
    $r->content($json_buf."\n");
#    warn $json_buf."\n";
    return $r;
}

sub yaw_normalize {
# --------------------------------------------------
# Ensure that the yaw is something between 0 and 
# 360
#
    my $yaw = shift;
    return (($yaw + 3600)%360);
}
