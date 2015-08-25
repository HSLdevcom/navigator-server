
vr = require 'vr'

# Convert route from the interface to proper ("JORE") route code
# (Route code is needed to match the routes properly in other systems)
route_to_code = (route) ->
    if "IKNTHRZ".indexOf(route) != -1
        # train, northern railroad
        return "3001" + route
    if "YSULEAMP".indexOf(route) != -1
        # train, western railroad (or M/P for Vantaankoski)
        return "3002" + route
    # something else, let's hope it's a route code already
    return ""+route

class VRPollClient
    constructor: (@callback, @args) ->
        @routes = {"": {}}
        @poll_delay = 10

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
        try
            vr.getTrain info.guid, (error, extended_info) =>
                if extended_info == null
                    return null

                out_info =
                    vehicle:
                        id: info.guid
                        label: info.guid
                    trip:
                        route: route_to_code(info.title)
                        direction: if info.from == "HKI" then "1" else "2"
                        start_time: extended_info.item[0].scheduledDepartTime.replace ':', ''
                        operator: "HSL"
                    position:
                        latitude: parseFloat info['georss:point'][0]
                        longitude: parseFloat info['georss:point'][1]
                        bearing: parseFloat info.dir
                        speed: (parseFloat extended_info.speed) / 3.6
                        delay: parseFloat extended_info.lateness
                        next_stop_index: (i for i in extended_info.item when i.completed == 1).length + 1
                    timestamp: new Date().getTime() / 1000

                # Create path/channel that is used for publishing the out_info for the
                # interested navigator-proto clients via the @callback function
                route = route_to_code(info.title).replace " ", "_"
                vehicle_id = out_info.vehicle.id.replace " ", "_"
                path = "/location/helsinki/#{route}/#{vehicle_id}"

                @callback path, out_info, @args

        catch error
            console.log("Error in fetching train data")

    poll_route: () ->
        route = @routes[""]
        try
            route.req = vr.getTrains (error,resp) =>
                if error != null
                    @set_poll_timer "", true
                    return

                for line in resp
                    if line.category != 2
                        continue
                    if line.status == 5
                        continue
                    @update_location line

                @set_poll_timer "", false
        catch e
            console.log("Error in fetching all trains")
            @set_poll_timer "", true

    connect: ->
        @poll_route()

module.exports.VRPollClient = VRPollClient
