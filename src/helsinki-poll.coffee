
http = require 'http'

col_names = [
    "id", "route", "lng", "lat", "bearing", "direction", "previous_stop", "next_stop", "departure"
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
    if "YSULEAMP".indexOf(route) != -1
        # train, western railroad (or M/P for Vantaankoski)
        return "3002" + route
    # something else, let's hope it's a route code already
    return route

class HSLPollClient
    constructor: (@callback, @args) ->
        @routes = {"": {}}
        @poll_delay = 1

    set_poll_timer: (route_name, is_error) ->
        route = @routes[route_name]
        if route.timeout
            clearTimeout route.timeout
        timeout_handler = =>
            route.timeout = null
            @poll_route route_name
        if is_error
            delay = @poll_delay * 10
        else
            delay = @poll_delay
        delay *= 1000
        route.timeout = setTimeout timeout_handler, delay

    update_location: (info) ->
        out_info =
            vehicle:
                id: info.id
                label: info.id
            trip:
                route: route_to_code(info.route)
                direction: info.direction
                start_time: info.departure
                operator: "HSL"
            position:
                latitude: parseFloat info.lat
                longitude: parseFloat info.lng
                bearing: parseFloat info.bearing
#                odometer: parseFloat info.distance_from_start
#                speed: (parseFloat info.speed) / 3.6
#                delay: -(parseFloat info.difference_from_timetable)
            timestamp: new Date().getTime() / 1000

        # Create path/channel that is used for publishing the out_info for the
        # interested navigator-proto clients via the @callback function
        route = route_to_code(info.route).replace " ", "_"
        vehicle_id = out_info.vehicle.id.replace " ", "_"
        path = "/location/helsinki/#{route}/#{vehicle_id}"

        @callback path, out_info, @args

    poll_route: () ->
        route = @routes[""]
        opts =
            host: '83.145.232.209'
            port: 10001
            path: "/?type=vehicles&lat1=0&lng1=0&lat2=90&lng2=90"
        
        route.req = http.get opts, (resp) =>
            data = ''
            route.req = null
            resp.on 'data', (chunk) =>
                data += chunk
            resp.on 'end', (chunk) =>
                if resp.statusCode != 200
                    console.log "request failed: code #{resp.statusCode}"
                    @set_poll_timer "", true
                    return

                lines = data.split /\r?\n/
                for line in lines
                    cols = line.split ';'

                    info = {}
                    for n, idx in col_names
                        info[n] = cols[idx]

                    if not info.route
                        continue

                    @update_location info

                @set_poll_timer "", false

        route.req.on 'error', (e) =>
            console.log "polling failed: " + e.message
            route.req = null
            @set_poll_timer "", true

    connect: ->
        @poll_route()

#cli = new HSLPollClient (()->console.log arguments)
#cli.connect()

module.exports.HSLPollClient = HSLPollClient
