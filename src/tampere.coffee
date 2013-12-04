http = require 'http'


class SiriJSONClient
    constructor: (@callback, @args) ->
        @routes = {"": {}}
        @poll_delay = 1

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

    update_location: (data) ->
        out_info =
            vehicle:
                id: data.MonitoredVehicleJourney.VehicleRef.value
            trip:
                route: data.MonitoredVehicleJourney.LineRef.value
                direction: data.MonitoredVehicleJourney.DirectionRef.value
                start_time: data.MonitoredVehicleJourney.FramedVehicleJourneyRef.DatedVehicleJourneyRef
                operator: data.MonitoredVehicleJourney.OperatorRef.value
            timestamp: data.RecordedAtTime / 1000
            position:
                latitude: data.MonitoredVehicleJourney.VehicleLocation.Latitude
                longitude: data.MonitoredVehicleJourney.VehicleLocation.Longitude
                bearing: data.MonitoredVehicleJourney.Bearing
                delay: data.MonitoredVehicleJourney.Delay
        route = out_info.trip.route
        vehicle = out_info.vehicle.id
        path = "/location/tampere/#{route}/#{vehicle}"
        @callback path, out_info, @args

    poll_route: () ->
        route = @routes[""]
        opts =
            host: '178.217.134.37'
            port: 8080
            path: "/siriaccess/vm/rest"
        
        route.req = http.get opts, (resp) =>
            data = ''
            route.req = null
            resp.on 'data', (chunk) =>
                data += chunk
            resp.on 'end', (chunk) =>
                if resp.statusCode != 200
                    console.log "request failed: code #{resp.statusCode}"
                    @.set_poll_timer "", true
                    return
                objs = JSON.parse data
                for vehicle in objs.Siri.ServiceDelivery.VehicleMonitoringDelivery[0].VehicleActivity
                    @.update_location vehicle
                @.set_poll_timer "", false
        route.req.on 'error', (e) =>
            console.log "polling failed: " + e.message
            route.req = null
            @.set_poll_timer "", true

    connect: ->
        @.poll_route()

#cli = new SiriJSONClient (()->console.log arguments)
#cli.connect()

module.exports.SiriJSONClient = SiriJSONClient
