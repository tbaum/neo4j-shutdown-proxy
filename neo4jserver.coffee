net = require "net"
mail = require('mail').Mail(host: 'localhost')

email_sender = 'hosted@neotechnology.com'
email_recipients = ['cloud@neotechnology.zendesk.com']

iptables = require "./iptables.coffee"

exec_org = require('child_process').exec

exec = (log, cmd, callback) ->
    log "exec:" + cmd
    exec_org cmd, (exit, out, err)->
        if (exit) then log "exit-code: " + exit
        if (out)  then log " > " + line for line in out.split "\n"
        if (err)  then log "E> " + line for line in err.split "\n"
        if (callback) then callback exit, out, err

class Neo4JServer
    constructor: (@config, @serverName) ->
        iptRule = iptables.redirectRule config.port, config.proxyPort
        running = false
        startingOrStopping = false
        inError = false
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

        sendErrorMessage = (info) ->
            message = mail.message
                from: email_sender
                to: email_recipients
                subject: serverName + ' ' + config.instance + ' could not start database'
            message.body info
            message.send (err)-> throw err if (err)

        sendRecoverMessage =  ->
            message = mail.message
                from: email_sender
                to: email_recipients
                subject: serverName + ' ' + config.instance + ' could not start database'
            message.body "== RECOVERED =="
            message.send (err)-> throw err if (err)

        updateStatus = @updateStatus = (callback)->
            if callback is undefined
                callback = (isRunning) -> setRunning isRunning if running != isRunning

            isOpen = false
            conn = net.createConnection(config.port, "localhost")
            timeoutId = setTimeout (()-> onClose()), 400
            onClose = ->
                clearTimeout timeoutId
                delete conn
                if isOpen && inError
                    sendRecoverMessage()
                    inError = false
                callback isOpen

            conn.on "close", onClose
            conn.on "error", -> conn.end()
            conn.on "connect", -> isOpen = true && conn.end()

        startServer = @startServer = (callback) ->
            if startingOrStopping
                callback "is allready starting/stopping" if callback
                log "try to start server: is allready starting/stopping"
                return

            if inError
                callback "in error state" if callback
                log "try to start server: in error state"
                return

            if running
                callback "is running" if callback
                log "try to start server: is running"
                return

            startingOrStopping = true
            log "starting"
            exec log, config.startCmd, (error, stdout, stderr) ->
                if error
                    sendErrorMessage stdout + '\n\n' + stderr
                    inError = true

                updateStatus (isRunning) ->
                    startingOrStopping = false
                    setRunning isRunning
                    callback "start " + isRunning if callback

        stopServer = @stopServer = (callback) ->
            if startingOrStopping
                callback "is allready starting/stopping" if callback
                log "try to stop server: is allready starting/stopping"
                return

            unless running
                callback "not running" if callback
                log "try to stop server: not running"
                return

            startingOrStopping = true
            log "stopping"
            exec log, config.stopCmd, ->
                startingOrStopping = false
                setRunning false
                callback "stopped" if callback

        waitForServer = @waitForServer = (msg, callback) ->
            return callback() if running
            # log "waitForServer " + msg
            startServer() unless startingOrStopping
            setTimeout waitForServer, 2000, msg, callback


exports.create = (config, serverName) -> new Neo4JServer(config, serverName)
