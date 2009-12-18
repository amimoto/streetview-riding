======================================================================
== README.TXT
======================================================================

Scripts and source for Stationary Cycling through Google Street View.

Sorry, this script is not really made for production use and for other 
people but I'm hoping that this is enough to give some inspiration to
someone else to take the concept to the next phase which is a reliable
and friendly implementation.

Quite a few parts of this are gross, especially the javascript.

THIS CODE IS FOR EXPERIENCED DEVELOPERS.

======================================================================
== LICENSE
======================================================================

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.


======================================================================
== SOFTWARE REQUIREMENTS
======================================================================

Linux (I used ubuntu 8.10)
Threads enabled Perl. (I used v5.10.0 built for i486-linux-gnu-thread-multi)
Perl libraries:
    JSON (JSON::XS for speed)
    HTTP::Daemon
    Time::HiRes
Arudino IDE

======================================================================
== FILES
======================================================================

Layout of the files:

bikeio.cpp  - Arduino sketch handling interface to the reed switch
ranges.pl   - acquire the range of values that the HMD produces
server.pl   - the HTTP microserver that interfaces with all the devices
templates/* - static files served by microserver and javascript code

======================================================================
== USING
======================================================================

1. Compile and upload the Arduino sketch to your device

2. Figure out where in dev your peripherals live:

   * Vuzix VR920
         - on my laptop, it showed up at
             /dev/usb/usbhid0
         - on the desktop, it showed up at
             /dev/usb/usbhid1
         If you cat the file, it should show a never ending stream 
         of seemingly repeating binary garbage.

   * Arduino Lilypad
         - In dmesg, look for a line like:
             FTDI USB Serial Device converter now attached to ttyUSB0
           This means that the serial device will be at
             /dev/ttyUSB0

3. Update the paths on in ranges.pl and server.pl

4. Run ranges and move the HMD around. When the numbers seem stable, copy 
   those numbers into server.pl

5. Run server.pl

6. Go to the URL specified

7. Deactivate debug mode if on

8. Click "Run"

9. Look in the direction that is "forward" for you and click "reset"

10. Look in the direction of travel and click "Fix Heading"

11. Start riding!

12. I think we both know that it won't be this easy.

======================================================================
== CONTACT
======================================================================

THIS CODE IS FOR EXPERIENCED DEVELOPERS.

With that warning, you can reach me at:

aki-streetviewriding@bako.ca
Aki Mimoto

