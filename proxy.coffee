net = require 'net'

class Proxy
    constructor: (neo4j, config) ->
        log = config.logger

        server = net.createServer (proxySocket) ->
            info = proxySocket.remoteAddress + ":" + proxySocket.remotePort
            log "handle connection " + info

            serverSocket = new net.Socket()
            proxySocket.on "data", (data) -> neo4j.waitForServer ">" + info, -> serverSocket.write data
            proxySocket.on "close", -> neo4j.waitForServer ">" + info, -> serverSocket.end()

            neo4j.waitForServer "<" + info, ->
                serverSocket.connect config.port, "127.0.0.1"
                serverSocket.on "data", (data) -> proxySocket.write data
                serverSocket.on "close", (had_error) -> proxySocket.end()

        log "start " + config.proxyPort + " -> " + config.port
        list = server.listen config.proxyPort

        updater = setInterval neo4j.updateStatus, 30000
        neo4j.updateStatus (isRunning) -> neo4j.setRunning isRunning

        @running = -> neo4j.running()

        @stop = ->
            clearInterval updater
            neo4j.stopServer()
            server.close()

        @startServer = (callback) ->
            neo4j.startServer callback

        @stopServer = (callback) ->
            neo4j.stopServer callback


exports.buildFor = (neo4j, config) -> new Proxy neo4j, config
