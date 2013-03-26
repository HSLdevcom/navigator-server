http = require 'http'


class TfGMClient
    constructor: (@callback, @args) ->
        @dev_key = 'e5541db9-e410-45d0-8481-08adf0a193ce'
        @app_key = '2c4abc94-240f-490e-bb86-880471640b37'
        @routes =
            '3':
                gtfs_name: 'GMN:   3:C:'
            '2':
                gtfs_name: 'GMN:   2:C:'
            '1':
                gtfs_name: 'GMN:   1:C:'
        @poll_delay = 5

    set_poll_timer: (route_name, is_error) ->
        route = @routes[route_name]
        if route.timeout
            clearTimeout route.timeout
        timeout_handler = =>
            route.timeout = null
            @.poll_route route_name
        if is_error
            delay = @poll_delay * 10
        else
            delay = @poll_delay
        delay *= 1000
        route.timeout = setTimeout timeout_handler, delay

    update_location: (route_name, data) ->
        out_info =
            vehicle:
                id: data['Registration']
            trip:
                route: @routes[route_name].gtfs_name
            timestamp: data['LastUpdated']
            position:
                latitude: data['Latitude']
                longitude: data['Longitude']
                bearing: data['Heading']
        route = out_info.trip.route.replace(/\ /g, "_").replace(/:/g, '-')
        path = "/location/manchester/#{route}/#{out_info.vehicle.id}"
        @callback path, out_info, @args

    poll_route: (route_name) ->
        route = @routes[route_name]
        opts =
            host: 'opendata.tfgm.com'
            path: "/api/routes/#{route_name}/buses"
            headers:
                'DevKey': @dev_key
                'AppKey': @app_key
        
        route.req = http.get opts, (resp) =>
            data = ''
            route.req = null
            resp.on 'data', (chunk) =>
                data += chunk
            resp.on 'end', (chunk) =>
                objs = JSON.parse data
                for vehicle in objs
                    if not vehicle['HasFix']
                        continue
                    @.update_location route_name, vehicle
                @.set_poll_timer route_name, false
        route.req.on 'error', (e) =>
            console.log "polling failed: " + e.message
            route.req = null
            @.set_poll_timer route_name, true

    connect: ->
        for route_name of @routes
            @.poll_route route_name

#cli = new TfGMClient
#cli.poll_route('MET1')
#cli.connect()

module.exports.TfGMClient = TfGMClient
