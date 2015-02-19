
net = require 'net'
Tail = require('tail').Tail
fs = require 'fs'
moment = require 'moment'
tz = require 'moment-timezone'
lineReader = require 'line-reader'

log_dir = "/home/hslhelmi/vehiclereport/"
log_file_start = "ITRADIOCOMM_"
log_file_end = ".LOG"
log_file_re = /^ITRADIOCOMM_.+\.LOG$/

calendar_file = "data/calendar.skv"
departures_file = "data/helmi_departures.csv"
stops_file = "data/node.txt"

# global state: a mapping from vehicle id to its current route code
vehicle_to_route = {}
calendars = {}
stops = {}
departures = {}

class HelmiClient
    constructor: (@callback, @args) ->
        lineReader.eachLine calendar_file, (line, last) ->
            calendars[line.split(';')[3]] = line.split(';')[4]
        lineReader.eachLine stops_file, (line, last) ->
            stops[line.split(';')[0]] = line.split(';')[1]
        lineReader.eachLine departures_file, (line, last) ->
            details = line.split(';')
            departures[details[0]] = [details[1], details[2], details[3]]
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
            today_log = log_dir + log_file_start +
                        moment().format('YYYY-MM-DD') + log_file_end
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
            return if route == 0 # discard if no information about route
            if route <= 10
                return # tram data is better elsewhere

            today = moment().tz('Europe/Helsinki').format('YYYYMMDD')
            if today of calendars
                calendar_type = calendars[today]
                trip_number = parseInt cols[7]
                departure = calendar_type + "_" + route + "_" + trip_number
                if departure of departures
                    departure_details = departures[departure]

            if departure_details
                route = departure_details[1]
                direction =  departure_details[0]
                start_time =  departure_details[2]
            else if route <= 100 and not (route in [61])
                route += 1000
            else if route in [506, 550, 552, 554]
                route += 2000
            else
                route += 4000
            info =
                route: "#{route}"
                trip: start_time
                direction: direction
                next_stop: stops[cols[8].replace /[ ]/g, '']
                stop_status: cols[9]
                distance_to_stop: cols[10]
                speed: cols[11]
                late_early: cols[12]
                delay: cols[13]
            vehicle_to_route[cols[5]] = info
            return # no position update to forward
        else
            return # unused message type

        if info.id of vehicle_to_route
            info.details = vehicle_to_route[info.id]
        else
            return # route unknown

        # Skip line if no coordinates supplied
        if info.lat == '0' or info.lng == '0'
            return
        timestamp = new Date().getTime() / 1000

        if info.details.delay and info.details.next_stop
            delay_multiplier = 0

            if info.details.late_early == "E" and
              info.trip < moment().tz('Europe/Helsinki').format('HHmm')
                delay_multiplier = -1
            else if info.details.late_early == "L"
                delay_multiplier = 1

            delay = delay_multiplier *
                (parseInt(info.details.delay.substring(0,2)) * 60 +
                 parseInt(info.details.delay.substring(3,5)))

        out_info =
            vehicle:
                id: info.id
                label: info.name
            trip:
                route: info.details.route
                direction: info.details.direction
                start_time: info.details.trip
                operator: "HSL"
            position:
                latitude: parseFloat info.lat / 1e6
                longitude: parseFloat info.lng / 1e6
#                bearing: parseFloat info.bearing
#                odometer: parseFloat info.distance_from_start
                speed: (parseFloat info.details.speed) / 3.6
                delay: delay
                next_stop: info.details.next_stop
            timestamp: timestamp
        # Create path/channel that is used for publishing the out_info for the
        # interested navigator-proto clients via the @callback function
        route = info.details.route.replace " ", "_"
        vehicle_id = out_info.vehicle.id.replace " ", "_"
        path = "/location/helsinki/#{route}/#{vehicle_id}"
        @callback path, out_info, @args

module.exports.HelmiClient = HelmiClient # make HSLClient visible in server.coffee
