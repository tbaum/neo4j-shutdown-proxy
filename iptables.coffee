
exec = require("child_process").exec

class IptablesRule
    constructor: (rule) ->
        isPresent = (condition, callback) ->
            exec "iptables -tnat -S PREROUTING", (x, o) ->
                if ( (o.indexOf(rule) != -1) == condition) then callback()

        @addRule = ->
            isPresent false, ->
                exec "iptables -tnat -A PREROUTING " + rule

        @removeRule = ->
            isPresent true, ->
                exec "iptables -tnat -D PREROUTING " + rule


exports.rule = (rule) -> new IptablesRule rule

exports.redirectRule = (port, proxyPort) ->
    new IptablesRule "-i eth0 -p tcp -m tcp --dport " + port + " -j REDIRECT --to-ports " + proxyPort
