http = require 'http'
faye = require 'faye'

# faye is used for handling lower level messaging between this navigator-server and
# navigator-clients.
bayeux = new faye.NodeAdapter
    mount: '/faye', timeout: 45

# Handle non-Bayeux requests
server = http.createServer (request, response) ->
  response.writeHead 200, {'Content-Type': 'text/plain'}
  response.write 'Nothing to see here'
  response.end()

bayeux.attach server
server.bayeux = bayeux
module.exports = server # Make server visible in the Gruntfile.coffee

bayeux.bind 'handshake', (client_id) ->
    console.log "client " + client_id + " connected"

client = bayeux.getClient()

handle_event = (path, msg) ->
    console.log "publishing to channel " + path #+ " message " + JSON.stringify(msg)
    client.publish path, msg

helsinki = require './helsinki.js'
manchester = require './manchester.js'
tampere = require './tampere.js'
helsinki_poll = require './helsinki-poll.js'
helmi = require './helmi.js'

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
