
http = require 'http'
faye = require 'faye'
url = require 'url'


# global state: a mapping from vehicle id to its latest data
state = {}

# conversion from vehicle data item to siri format VehicleActivity entry
to_vehicleactivity_item = (now, data) ->
  ValidUntilTime: data.timestamp*1000+30*1000
  RecordedAtTime: data.timestamp*1000
  MonitoredVehicleJourney:
    LineRef: value: data.trip.route
    DirectionRef: value: data.trip.direction
    FramedVehicleJourneyRef:
      # XXX should DataFrameRef increment at midnight or in the morning?
      DataFrameRef: value: "#{now.getYear()+1900}-#{(now.getMonth()+1+100).toString().substring(1)}-#{(now.getDate()+100).toString().substring(1)}"
      DatedVehicleJourneyRef: data.trip.start_time
    OperatorRef: value: data.trip.operator
# XXX unimplemented:
#    OriginName:
#      value:
#      lang:
#    DestinationName:
#      value:
#      lang:
    Monitored: true
    VehicleLocation:
      Longitude: data.position.longitude
      Latitude: data.position.latitude
    Bearing: data.position.bearing
    Delay: data.position.delay
    MonitoredCall:
      StopPointRef: data.position.next_stop
      Order: data.position.next_stop_index
    VehicleRef: value: data.vehicle.id


# faye is used for handling lower level messaging between this navigator-server and
# navigator-clients.
bayeux = new faye.NodeAdapter
    mount: '/faye', timeout: 45

# Handle non-Bayeux requests
server = http.createServer (request, response) ->
  console.log "#{request.method} #{request.url}"
  query = url.parse(request.url, true).query
  pathname = url.parse(request.url).pathname
  if pathname == "/" or pathname == "faye"
    response.writeHead 200, {'Content-Type': 'text/plain'}
    response.write 'Nothing to see here'
    response.end()
  else if pathname == "/siriaccess/vm/json"
    now = new Date()
    response.writeHead 200, {'Content-Type': 'application/json'}
    response.write JSON.stringify
      Siri:
        version: "1.3"
        ServiceDelivery:
          ResponseTimestamp: now.getTime()
          ProducerRef: value: "HSL"
          Status: true
          MoreData: false
          VehicleMonitoringDelivery:
            [
              version: "1.3"
              ResponseTimestamp: now.getTime()
              Status: true
              VehicleActivity: (to_vehicleactivity_item(now, data) for id, data of state when true and
                (not query.lineRef? or data.trip.route == query.lineRef) and
                (not query.operatorRef? or data.trip.operator == query.operatorRef) and
                now.getTime() < data.timestamp*1000 + 60*1000)
            ]
    response.end()
  else
    response.writeHead 404, {'Content-Type': 'text/plain'}
    response.write "Not found: #{request.url}"
    response.end()
    
  
bayeux.attach server
server.bayeux = bayeux
module.exports = server # Make server visible in the Gruntfile.coffee

bayeux.bind 'handshake', (client_id) ->
    console.log "client " + client_id + " connected"

client = bayeux.getClient()

handle_event = (path, msg) ->
    state[msg.vehicle.id] = msg
    client.publish path, msg

helsinki = require './helsinki.js'
manchester = require './manchester.js'
tampere = require './tampere.js'
helsinki_poll = require './helsinki-poll.js'
helmi = require './helmi.js'
vr_poll = require './vr_poll.js'

# Create new real-time data converters, hel_client and man_client, and pass handle_event
# function for them that is used for publishing real-time public transport data to the
# city-navigator clients that connect to this server. After creating a converter call
# it's connect function to connect to the real-time data provider, for example,
# HSL Live server.
hel_client = new helsinki.HSLClient handle_event
hel_client.connect()
man_client = new manchester.TfGMClient handle_event
man_client.connect()
tre_client = new tampere.SiriJSONClient handle_event
tre_client.connect()
hsl_poll_client = new helsinki_poll.HSLPollClient handle_event
hsl_poll_client.connect()
helmi_client = new helmi.HelmiClient handle_event
helmi_client.connect()
vr_poll_client = new vr_poll.VRPollClient handle_event
vr_poll_client.connect()
