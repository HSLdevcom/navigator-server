http = require 'http'
faye = require 'faye'
net = require 'net'
carrier = require 'carrier'

bayeux = new faye.NodeAdapter
    mount: '/faye', timeout: 45

# Handle non-Bayeux requests
server = http.createServer (request, response) ->
  response.writeHead 200, {'Content-Type': 'text/plain'}
  response.write 'Nothing to see here'
  response.end()

bayeux.attach server
module.exports = server

bayeux.bind 'handshake', (client_id) ->
    console.log "client " + client_id + " connected"

bay_client = bayeux.getClient()

hsl_client = net.connect 8080, '83.145.232.209'
hsl_client.write '&okffin;tuusula1 type:1&'

col_names = [
    "id", "name", "type", "ip", "lat", "lng", "speed", "bearing",
    "acceleration", "gps_time_difference", "unix_epoch_gps_time", "low_floor", "route", "direction",
    "departure", "departure_time", "departure_stars_in", "distance_from_start", "snapped_lat", "snapped_lng",
    "snapped_bearing", "next_stop_index", "on_stop", "difference_from_timetable"
]

event_carrier = carrier.carry hsl_client
event_carrier.on 'line', (line) ->
    cols = line.split ';'
    if cols.length < 10
        return
    info = {}
    for n, idx in col_names
        info[n] = cols[idx]
    # Skip line if no coordinates supplied
    if info.lat == '0' or info.lng == '0'
        return
    timestamp = (parseInt info.unix_epoch_gps_time) / 1000
    if timestamp <= 0
        return
    if not info.route
        return
    out_info =
        vehicle:
            id: info.id
            label: info.name
        trip:
            route: info.route
            direction: info.direction
        position:
            latitude: parseFloat info.lat
            longtitude: parseFloat info.lng
            bearing: parseFloat info.bearing
            odometer: parseFloat info.distance_from_start
            speed: (parseFloat info.speed) / 3.6
        timestamp: (parseInt info.unix_epoch_gps_time) / 1000
    #console.log info
    path = "/location/helsinki/#{out_info.trip.route}/#{out_info.vehicle.id}"
    #console.log path
    #console.log out_info
    bay_client.publish path, out_info
