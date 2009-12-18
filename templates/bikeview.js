/*

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

*/
var sv_pano;
var sv_client;
var sv_previous;
var sv_current;
var sv_heading               = 0;
var sv_heading_tolerance     = 15; // require at least 30 degrees before acceptance
var sv_hmd_heading_tolerance = 30;
var sv_node_distance         = 0;
var sv_true_distance         = 0;

var start_pov                = {yaw:0,pitch:0};
var start_location           = new GLatLng(49.263048,-123.163694);

var tics_last                = 0;
var tics_start               = new Date();

var tics_status_poll         = 100;
var poll_pause               = 1;

$(function(){
// Setup the objects
  jQuery.getJSON('/reset_run.json');

  sv_pano        = new GStreetviewPanorama(document.getElementById("pano"));
  sv_client      = new GStreetviewClient();
  
// Setup the initial position of the streetview 
  sv_pano.setLocationAndPOV(start_location, start_pov);
  sv_client.getNearestPanorama(start_location,pano_moved);

// Setup the hmd status poll
  $().everyTime(tics_status_poll,status_poll);
});

function status_poll () {
// --------------------------------------------------
// Request an update from the server every tics_status_poll 
// milliseconds so that we can move the user from one place 
// to another or update the POV as required :)
//
    var data = {};
    var now  = new Date();

// Should only be used while the streetview is updating to a new location
    if ( poll_pause ) {
        return;
    };

// We don't want to double up requests so we will wait 1 second before
// issuing a new request if it hung
    if ( tics_last && ( now.getTime() - 1000 < tics_last.getTime() ) ) {
        return;
    }

// only run the poll if the RUN checkbox has been checked.
    if ( ! $('#RUN').is(':checked') ) {
      return;
    }

// Record that we're starting a new request.
    tics_last = now;
    jQuery.getJSON( 
        '/request_update.json', 
        data, 
        function ( data ) {
        // --------------------------------------------------
        // Receive the current status of the HMD and distance
        // travelled on the bike.
        //
          var pov   = sv_pano.getPOV() 
          pov.yaw   = yaw_normalize( data.yaw + sv_heading );
          pov.pitch = data.pitch;
          sv_true_distance = data.distance;
          sv_pano.setPOV(pov);
          debug_log( "Yaw: " + pov.yaw + " Pitch: " + pov.pitch + " Distance: " + sv_true_distance);
          tics_last = null;
          node_move();
        }
    );
}

function node_move () {
// --------------------------------------------------
// Check if the user has moved to a new node.
//

// Find out how far we've moved while sitting on
// this node.
    var node_distance = sv_true_distance - sv_node_distance;

// At this point we can iterate through each of the
// links on this location and see if we can match it
// up to the heading we're looking at
    var sv_location    = sv_current.location;
    var sv_start_coord = sv_location.latlng;
    var sv_links       = sv_current.links;
    var pov            = sv_pano.getPOV() 
    var yaw_tests      = [[pov.yaw,sv_hmd_heading_tolerance],[sv_heading,sv_heading_tolerance]];

// We first check to see if the user is /looking/ in a direction we want to go.
// Then if that doesn't work, we will check to see if the user is already moving in a
// direction so we can keep them heading the right way.
    for ( j=0; j<yaw_tests.length;j++ ) {
      var pov_test = yaw_tests[j];
      var yaw_test = pov_test[0];
      var heading_tolerance = pov_test[1];

// Now iterate through the links...
      for ( i=0; i<sv_links.length;i++) {
          var sv_candidate   = sv_links[i];
          dev_log( yaw_test );

  // Is this link within the acceptable range for 
  // moving to? (ie. within view?)
          var yaw_difference = Math.abs( sv_candidate.yaw - yaw_test );
          debug_log("Yaw difference: " + yaw_difference + " heading tolerance: " + heading_tolerance );
          if ( 
              yaw_difference              > heading_tolerance 
              && ( 360 - yaw_difference ) > heading_tolerance 
          ) {
              continue;
          }

  // Are we within range of the destination?
          if ( ! sv_candidate.location ) {
              continue;
          }

          var sv_dest_coord  = sv_candidate.location.latlng;
          debug_log("About to test distance to destination Id: "+sv_dest_coord);
          var sv_dest_distance = sv_start_coord.distanceFrom(sv_dest_coord);
          debug_log( "Distance away: " + sv_dest_distance + " and so far we have gone " 
                                       + node_distance + " on this node ");
          if ( sv_dest_distance > node_distance ) {
              continue;
          }

  // Okay, we've travelled as far as the new destination location.
  // Let's go forward
          sv_node_distance += sv_dest_distance;
          pano_move( sv_candidate );
          return;
      }
    }
}

function pano_move ( sv_link ) {
// --------------------------------------------------
// Move the viewpoint to a new location. We'll
// need to do a bunch of updates along the way
//
    poll_pause = 1;
    sv_heading = sv_link.yaw;
    sv_pano.followLink(sv_link.yaw);
    sv_client.getPanoramaById( sv_link.panoId, pano_moved );
}

function pano_moved ( sv_data ) {
// --------------------------------------------------
// When the new location has been loaded. This probably
// ain't the best place to let the status poller 
// start running again but if it works... :}
//
    sv_previous = sv_current;
    sv_current  = sv_data;
    var sv_links       = sv_current.links;
    for ( i=0; i<sv_links.length;i++) {
        var sv_candidate   = sv_links[i];
        debug_log( "Requesting data for: " + sv_candidate.panoId );
        sv_client.getPanoramaById( sv_candidate.panoId, populate_link_data );
    }
    poll_pause  = 0;
}

function populate_link_data ( sv_data ) {
// --------------------------------------------------
// Just store in a hash, the target location's information
//
    var sv_location    = sv_data.location;
    var sv_links       = sv_current.links;
    debug_log( "Got data for: " + sv_location.panoId );
    for ( i=0; i<sv_links.length;i++) {
        var sv_candidate   = sv_links[i];
        if ( sv_candidate.panoId !=  sv_location.panoId ) continue;
        sv_candidate.location = sv_location;
    };
}

function heading_fix () {
// --------------------------------------------------
// We will fix the currently viewed heading to become
// the natural direction
//
    var pov    = sv_pano.getPOV() 
    sv_heading = yaw_normalize( pov.yaw );
    debug_log( "Fixed the heading to yaw: " + sv_heading );
    return false;
}

function yaw_normalize ( yaw ) {
// --------------------------------------------------
// Just ensures that the yaw is somewhere between 0 and
// 360 
//
    return ( ( yaw + 3600 ) % 360 )
}


function debug_log ( message ) {
// --------------------------------------------------
// Just dump any debugging information to the log if 
// we're actively receiving data
//
    if ( $('#LOGDEBUG').is(':checked') ) {
        $('#STDERR').val( 
            message + "\n" + $('#STDERR').val()
        );
    }
}

function dev_log ( message ) {
// --------------------------------------------------
// Just dump any debugging information to the log 
// no matter what. Intended for temporary usage.
//
return;
    $('#STDERR').val( 
        message + "\n" + $('#STDERR').val()
    );
}

