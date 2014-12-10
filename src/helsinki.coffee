net = require 'net'
carrier = require 'carrier'

# col_names corresponds to the message structure received from HSL Live server
# (Realtime API of vehicle locations)
col_names = [
    "id", "name", "type", "ip", "lat", "lng", "speed", "bearing",
    "acceleration", "gps_time_difference", "unix_epoch_gps_time", "low_floor", "route", "direction",
    "departure", "departure_time", "departure_stars_in", "distance_from_start", "snapped_lat", "snapped_lng",
    "snapped_bearing", "next_stop_index", "on_stop", "difference_from_timetable"
]

# Convert route from the interface to proper ("JORE") route code
# (The interface doesn't report route code for metro and train)
# (Route code is needed to disambiguate routes in different cities)
route_to_code = (route) ->
    if route == "1"
        # metro, Mellunmäki branch
        return "1300M"
    if route == "2"
        # metro, Vuosaari branch
        return "1300V"
    if "IKNTHRZ".indexOf(route) != -1
        # train, northern railroad
        return "3001" + route
    if "YSULEAM".indexOf(route) != -1
        # train, western railroad (or M for Vantaankoski)
        return "3002" + route
    # something else, let's hope it's a route code already
    return route

# HSLClient connects to HSL Live server (Realtime API of vehicle locations) and
# converts the received real-time data to the format used by city-navigator clients.
# HSLClient uses @callback function (defined in server.coffee) to publish the data
# to the clients.
class HSLClient
    constructor: (@callback, @args) ->

    connect: ->
        # Connect to HSL Live server via PUSH interface
        @client = net.connect 8080, '83.145.232.209' 
        @client.on 'connect', (conn) =>
            console.log "HSLClient connected"
            # Tell the HSL Live server that we want just info of the vehicles logged on route
            @client.write '&okffin;tuusula1 onroute:1&'

        line_handler = (line) =>
            @.handle_line line
        # We use carrier module to receive new-line terminated messages from HSL Live server
        # and pass those lines to the handle_line function
        @carrier = carrier.carry @client 
        @carrier.on 'line', line_handler

    # handle_line function creates out_info objects of the lines received from carrier
    # and calls @callback to handle the created out_info objects. The out_info object
    # format should be same as for the manchester.coffee.
    handle_line: (line) ->
        #console.log "Received line " + JSON.stringify(line)
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
                route: route_to_code(info.route)
                direction: info.direction
                start_time: info.departure
                operator: "HSL"
            position:
                latitude: parseFloat info.lat
                longitude: parseFloat info.lng
                bearing: parseFloat info.bearing
                odometer: parseFloat info.distance_from_start
                speed: (parseFloat info.speed) / 3.6
                delay: -(parseFloat info.difference_from_timetable)
                next_stop_index: (parseInt info.next_stop_index) + 1
            timestamp: (parseInt info.unix_epoch_gps_time) / 1000
        # Create path/channel that is used for publishing the out_info for the
        # interested navigator-proto clients via the @callback function
        route = route_to_code(info.route).replace " ", "_"
        vehicle_id = out_info.vehicle.id.replace " ", "_"
        path = "/location/helsinki/#{route}/#{vehicle_id}"
        @callback path, out_info, @args

module.exports.HSLClient = HSLClient # make HSLClient visible in server.coffee
