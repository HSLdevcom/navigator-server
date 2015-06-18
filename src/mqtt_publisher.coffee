moment = require 'moment'


mqtt_match = (pattern, topic) ->
    regex = pattern.replace(/\+/g, "[^/]*").replace(/\/#$/, "/.*")
    return topic.match "^"+regex+"$"


to_mqtt_topic = (msg) ->
    x = msg.position.latitude
    y = msg.position.longitude
    digit = (x, i) -> "" + Math.floor(x*10**i)%10
    digits = (digit(x, i) + digit(y, i) for i in [1..3])
    geohash = Math.floor(x) + ";" + Math.floor(y) + "/" + digits.join '/'

    route = msg.trip.route
    if route.match /^1300/
        mode = "subway"
    else if route.match /^300/
        mode = "rail"
    else if route.match /^10(0|10)/
        mode = "tram"
    else
        mode = "bus"

    return "/hfp/journey/#{mode}/#{msg.vehicle.id}/#{msg.trip.route}/#{msg.trip.direction}/XXX/#{msg.trip.start_time}/#{msg.position.next_stop}/"+geohash


to_mqtt_payload = (msg) ->
    VP:
        desi: msg.trip.route
        dir: msg.trip.direction
        oper: "XXX"
        veh: msg.vehicle.id
        tst: moment(msg.timestamp*1000).toISOString()
        tsi: Math.floor(msg.timestamp)
        spd: Math.round(msg.position.speed*100)/100
        hdg: msg.position.bearing
        lat: msg.position.latitude
        long: msg.position.longitude
        dl: msg.position.delay
        odo: msg.position.odometer
        oday: "XXX"
        jrn: "XXX"
        line: msg.trip.route
        start: msg.trip.start_time
        stop_index: msg.position.next_stop_index


module.exports =
    to_mqtt_topic: to_mqtt_topic
    to_mqtt_payload: to_mqtt_payload
    mqtt_match: mqtt_match
