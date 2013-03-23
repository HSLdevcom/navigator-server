http = require 'http'
faye = require 'faye'

bayeux = new faye.NodeAdapter
    mount: '/faye', timeout: 45

# Handle non-Bayeux requests
server = http.createServer (request, response) ->
  response.writeHead 200, {'Content-Type': 'text/plain'}
  response.write 'Nothing to see here'
  response.end()

bayeux.attach server
server.bayeux = bayeux
module.exports = server

bayeux.bind 'handshake', (client_id) ->
    console.log "client " + client_id + " connected"

client = bayeux.getClient()

handle_event = (path, msg) ->
    console.log path
    client.publish path, msg

helsinki = require './helsinki.js'
manchester = require './manchester.js'

hel_client = new helsinki.HSLClient handle_event
hel_client.connect()
man_client = new manchester.TfGMClient handle_event
man_client.connect()
