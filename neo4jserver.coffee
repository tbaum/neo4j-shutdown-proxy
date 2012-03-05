http = require "http"
iptables = require "./iptables.coffee"

exec_org = require('child_process').exec

exec = (log, cmd, callback) ->
    log "exec:"+cmd
    exec_org cmd, (exit, out, err)->
        if (exit) then log "exit-code: "+exit
        if (out)  then log " > " + line for line in out.split "\n"
        if (err)  then log "E> " + line for line in err.split "\n"
        if (callback) then callback exit, out, err


class Neo4JServer
    constructor: (@config, @serverName) ->
        iptRule = iptables.redirectRule config.port, config.proxyPort
        running = false
        startingOrStopping = false
        config = @config
        serverName = @serverName
        log = config.logger

        @running = -> running

        @setRunning = setRunning = (r) ->
            running = r
            if (running)
                log "remove firewall rule"
                iptRule.removeRule()
            else
                log "add firewall rule"
                iptRule.addRule()

        updateStatus = @updateStatus = ( callback )->
            if callback is undefined
                callback = (isRunning) -> setRunning isRunning if running != isRunning

            log "check status"
            request = http.request
                port: config.port, method: 'GET', path: '/admin/statistic/', host: '127.0.0.1'
                headers:
                    Host:'localhost', Accept:"application/json"
                    Authorization: 'Basic ' + new Buffer(config.adminCredentials).toString('base64')
                (response)->
                    now = new Date().getTime() / 1000
                    response.setEncoding 'utf8'
                    data = ""
                    response.on 'data', (chunk) -> data += chunk
                    response.on 'end', ->
                        callback true
                        requestCount = 0
                        duration = 0
                        try 
                         for sample in JSON.parse(data)
                            if (sample.timeStamp > (now - 86400))
                                requestCount += sample.requests
                                duration += sample.period
                        catch e 
                          console.log e

                        userRequests = requestCount - 10 - Math.round duration / 30

                        log "requests: " + requestCount + " in " + duration + "s --> " + userRequests
                        if userRequests <= 0  && duration > 82800  ## 23 hours
                            log "will shutdown"
                            stopServer()

            request.on 'error', (e) -> callback false
            request.end "\n"

        startServer = @startServer = ->
            return log "try to start server: is allready starting/stopping" if startingOrStopping
            return log "try to start server: is running" if running

            startingOrStopping = true
            log "starting"
            exec log, config.startCmd, (error, stdout, stderr) ->
                if error && !config.failedMail
                    config.failedMail = 1
                    subject = '[ERR-heroku] keeper coud not start '+config.startCmd+' on `hostname -f`'
                    exec log, '( date ; echo \''+stdout+'\' ; echo "'+config.port+' -----" ; tail -n30 /mnt/'+config.instance+'/data/log/console.log ) | mail heroku@neo4j.org -a "From: root@'+serverName+'" -s "'+subject+'"'
                updateStatus (isRunning) ->
                    config.failedMail = 0 if isRunning
                    startingOrStopping = false
                    setRunning isRunning

        stopServer = @stopServer = ->
            return log "try to stop server: is allready starting/stopping" if startingOrStopping
            return log "try to stop server: not running" unless running
            startingOrStopping = true
            log "stopping"
            exec log, config.stopCmd, ->
               startingOrStopping = false
               setRunning false

        waitForServer = @waitForServer = (msg, callback) ->
            return callback() if running
            log "waitForServer " + msg
            startServer() unless startingOrStopping
            setTimeout waitForServer, 2000, msg, callback


exports.create = (config,serverName) -> new Neo4JServer(config,serverName)
