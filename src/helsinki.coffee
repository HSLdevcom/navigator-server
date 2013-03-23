net = require 'net'
carrier = require 'carrier'

col_names = [
    "id", "name", "type", "ip", "lat", "lng", "speed", "bearing",
    "acceleration", "gps_time_difference", "unix_epoch_gps_time", "low_floor", "route", "direction",
    "departure", "departure_time", "departure_stars_in", "distance_from_start", "snapped_lat", "snapped_lng",
    "snapped_bearing", "next_stop_index", "on_stop", "difference_from_timetable"
]

class HSLClient
    constructor: (@callback, @args) ->

    connect: ->
        @client = net.connect 8080, '83.145.232.209'
        @client.on 'connect', (conn) =>
            console.log "HSLClient connected"
            @client.write '&okffin;tuusula1 onroute:1&'

        line_handler = (line) =>
            @.handle_line line
        @carrier = carrier.carry @client
        @carrier.on 'line', line_handler

    handle_line: (line) ->
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
                longitude: parseFloat info.lng
                bearing: parseFloat info.bearing
                odometer: parseFloat info.distance_from_start
                speed: (parseFloat info.speed) / 3.6
            timestamp: (parseInt info.unix_epoch_gps_time) / 1000
        route = info.route.replace " ", "_"
        vehicle_id = out_info.vehicle.id.replace " ", "_"
        path = "/location/helsinki/#{route}/#{vehicle_id}"
        @callback path, out_info, @args

module.exports.HSLClient = HSLClient
