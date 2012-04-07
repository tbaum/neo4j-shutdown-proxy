fs = require('fs')

class FileWatcher
    constructor: (file) ->
        @listen "/mnt/" + file + "/data/graph.db/messages.log"
        @listen "/mnt/" + file + "/data/log/console.log"
        @listen "/mnt/" + file + "/data/log/neo4j.log"

    watching = []

    listen: (file) ->
        return if watching[file]

        try
            console.log fs.statSync(file).isFIFO
        catch e
            console.log e

        console.log "start watch " + file

        watching[file] = stream = fs.createReadStream(file, {encoding: "UTF8"})

        stream.on "data", (d)->
            console.log file + " " + d

        self = this

        stream.on "end", ->
            console.log file + " end"
            delete watching[file]
            self.listen file

        stream.on "error", (e)->
            console.log file + " error " + e
            delete watching[file]
            try
                stream.close()
            catch e
                consoloe.log e


#stream.on "close", ->
#    console.log file + " close"


f = new FileWatcher("024ed856b")