fs = require 'fs'

class Neo4JConfiguration
    constructor: (instance) ->
        @instance = instance
        home = "/mnt/" + instance
        configData = fs.readFileSync home + "/conf/neo4j-server.properties", "UTF-8"
        port = @port = Number /org.neo4j.server.webserver.port=(.+)/.exec(configData)[1]
        @adminCredentials = /org.neo4j.server.credentials=(.+)/.exec(configData)[1]
        @proxyPort = this.port + 1000
        @startCmd = home + "/bin/neo4j start"
        @statusCmd = home + "/bin/neo4j status"
        @stopCmd = home + "/bin/neo4j stop"
        @logger = (message) -> console.log instance + ":" + port + " " + message


exports.parse = (instance) -> new Neo4JConfiguration instance