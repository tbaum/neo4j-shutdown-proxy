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
    constructor: (@config) ->
        iptRule = iptables.redirectRule config.port, config.proxyPort
        running = false
        starting = false
        config = @config

        log = (message) -> console.log config.instance + " " + message
        
        setRunning = (r) ->
            running = r
            if (running)
                log "remove firewall rule"
                iptRule.removeRule()
            else
                log "add firewall rule"
                iptRule.addRule()

        updateStatus = @updateStatus = ->
            exec log, config.statusCmd, (error, stdout) ->
                setRunning(stdout.indexOf("not running") == -1)
                checkIdle()

        checkIdle = @checkIdle = ->
            if (running)
                request = http.request
                    port: config.port, method: 'GET', path: '/admin/statistic/', host: '127.0.0.1',
                    headers:
                        Host:'localhost', Accept:"application/json"
                        Authorization: 'Basic ' + new Buffer(config.adminCredentials).toString('base64'),
                    (response)->
                        now = new Date().getTime() / 1000
                        response.setEncoding 'utf8'
                        data = ""
                        response.on 'data', (chunk) -> data += chunk
                        response.on 'end', ->
                            requestCount = 0
                            period = 0
                            for i in JSON.parse(data)
                                if (i['timeStamp'] > (now - 7200))
                                    requestCount += i['requests']
                                    period += i['period']

                            log "request-count for "+ config.port + " == " + requestCount + "/" + period

                request.on 'error', (e) ->
                    log "problem with request: " + e.message
                    setRunning false

                request.end "\n"

        startServer = @startServer = ->
            log "try to start server"
            if (starting || running)
                log "is running(=" + running + ") or starting(=" + starting + ")"
                return

            starting = true
            log "starting"
            exec log, config.startCmd, (error, stdout, stderr) ->
                starting = false
                if (error == null) then setRunning true
                else if (stdout.indexOf("already running with pid") != -1) then updateStatus()

        @stopServer = ->
            log "try to stop server"
            if (!running && !starting)
                log "not running(=" + running + ") or starting(=" + starting + ")"
                return

            starting = true
            log "stopping"
            exec log, config.stopCmd, (error, stdout, stderr) ->
               starting = false
               setRunning false

        waitForServer = @waitForServer = (msg, callback) ->
            if (running)
                callback()
            else
                log "wait " + msg
                if (!starting) then startServer()
                setTimeout waitForServer, 2000, msg, callback


exports.create = (config) -> new Neo4JServer(config)
