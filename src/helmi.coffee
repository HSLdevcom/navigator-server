
net = require 'net'
Tail = require('tail').Tail;


# global state: a mapping from vehicle id to its current route code
vehicle_to_route = {}

class HelmiClient
    constructor: (@callback, @args) ->

    connect: ->
        # FIXME need to open today's log and switch at each midnight
        tail = new Tail("/home/haphut/vehiclereport/ITRADIOCOMM_2013-12-04.LOG")
        tail.on "line", (line) =>
            @handle_line line

    # handle_line function creates out_info objects of the lines received
    # and calls @callback to handle the created out_info objects. 
    # The out_info object format should be same as for the manchester.coffee.
    handle_line: (line) ->
        cols = line.split ';'
        if cols.length < 10
            return # incomplete message

        if cols[3] == "POSITION "
            info = 
                id: cols[5]
                lat: cols[9]
                lng: cols[7]
        else if cols[3] == "REPORT_F8"
            route = parseInt cols[6]
            return if route == 0
            if route <= 10
                return # tram data is better elsewhere
            else if route <= 100
                route += 1000
            else if route in [506, 550, 552, 554]
                route += 2000
            else
                route += 4000
            vehicle_to_route[cols[5]] = "#{route}"
            return # no position update to forward
        else
            return # unused message type

        if info.id of vehicle_to_route
            info.route = vehicle_to_route[info.id]
        else
            return # route unknown

        # Skip line if no coordinates supplied
        if info.lat == '0' or info.lng == '0'
            return
        timestamp = new Date().getTime() / 1000

        out_info =
            vehicle:
                id: info.id
                label: info.name
            trip:
                route: info.route
                direction: info.direction
                start_time: info.departure
                operator: "HSL"
            position:
                latitude: parseFloat info.lat / 1e6
                longitude: parseFloat info.lng / 1e6
#                bearing: parseFloat info.bearing
#                odometer: parseFloat info.distance_from_start
#                speed: (parseFloat info.speed) / 3.6
#                delay: -(parseFloat info.difference_from_timetable)
            timestamp: timestamp
        # Create path/channel that is used for publishing the out_info for the
        # interested navigator-proto clients via the @callback function
        route = info.route.replace " ", "_"
        vehicle_id = out_info.vehicle.id.replace " ", "_"
        path = "/location/helsinki/#{route}/#{vehicle_id}"
        @callback path, out_info, @args

module.exports.HelmiClient = HelmiClient # make HSLClient visible in server.coffee
