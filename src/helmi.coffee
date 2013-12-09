
net = require 'net'
Tail = require('tail').Tail
fs = require 'fs'
moment = require 'moment'

log_dir = "/home/haphut/vehiclereport/"
log_file_start = "ITRADIOCOMM_"
log_file_end = ".LOG"
log_file_re = /^ITRADIOCOMM_.+\.LOG$/

# global state: a mapping from vehicle id to its current route code
vehicle_to_route = {}

class HelmiClient
    constructor: (@callback, @args) ->
        @tail = null

    connect: ->
        watcher = fs.watch log_dir, (event, filename) =>
            # React only on new or removed files.
            if event == 'rename'
                console.log('event:', event, '---', 'filename:', filename)
                # Assume that new files matching the regex are more recent
                # than the current one.
                if log_file_re.test(filename)
                    # Open to test that 'rename' was not triggered because
                    # of a removal.
                    fs.open "#{log_dir}#{filename}", 'r', (err, fd) =>
                        if not err?
                            fs.close(fd, console.log)
                            if @tail?
                                # Release previous log file.
                                @tail.unwatch()
                            @tail = new Tail("#{log_dir}#{filename}")
                            @tail.on "line", (line) =>
                                @handle_line line
                        else
                            console.log(err)

        if not @tail?
            # Assume that today's log file exists on startup.
            today_log = log_dir + log_file_start + moment().format('YYYY-MM-DD') + log_file_end
            @tail = new Tail(today_log)
            @tail.on "line", (line) =>
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
