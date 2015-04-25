window.app = angular.module 'session-info', [
    'ngAnimate'
    'ngSanitize'
]

app.service 'config', ($location) ->
    vars = $location.search()

    fps = 2

    host: vars.host or '127.0.0.1:8182'
    fps: fps

app.service 'iRData', ($rootScope, config) ->
    requestParams = [
        # yaml
        'SessionInfo'

        # telemetry
        'SessionNum'
        'SessionState'
        'SessionFlags'
        'SessionTime'
        'SessionTimeRemain'
    ]

    ir = new IRacing \
        # request params
        requestParams,
        # request params once
        [],
        config.fps,
        config.host,
        config.showTyres

    ir.onConnect = ->
        ir.data.connected = true
        $rootScope.$apply()

    ir.onDisconnect = ->
        ir.data.connected = false
        $rootScope.$apply()

    ir.onUpdate = (keys) ->
        $rootScope.$apply()

    return ir.data

app.controller 'SessionCtrl', ($scope, $element, iRData) ->
    $scope.ir = iRData

    $scope.$watch 'ir.connected', (n, o) ->
        $element.toggleClass 'ng-hide', not n

app.directive 'appSessionLap', (iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData
        sessionLaps = null

        updateSessionLap = ->
            session = ir.SessionInfo.Sessions[ir.SessionNum]

            if session.ResultsLapsComplete == -1
                lap = 0
            else
                lap = session.ResultsLapsComplete

            if ir.SessionState >= 5
                element.html 'Finish'
            else
                element.html "#{lap}" + (if sessionLaps then "/#{sessionLaps}" else '')

        updateSessionLaps = ->
            if not ir.SessionInfo or not (ir.SessionNum >= 0)
                sessionLaps = null
                return
            session = ir.SessionInfo.Sessions[ir.SessionNum]
            sessionLaps = session.SessionLaps
            updateSessionLap()

        scope.$watch 'ir.SessionNum', updateSessionLaps
        scope.$watch 'ir.SessionInfo', updateSessionLaps
        scope.$watch 'ir.SessionState', updateSessionLaps

        scope.$watch 'ir.connected', (n, o) ->
            sessionLaps = null

app.directive 'appSessionTime', (iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData

        updateSessionTime = ->
            if not ir.SessionInfo
                return

            session = ir.SessionInfo.Sessions[ir.SessionNum]
            totalSessionTime = parseInt session.SessionTime

            if 0 < ir.SessionTimeRemain < 604800 and ir.SessionTime < totalSessionTime
                time = ir.SessionTimeRemain
            else 
                time = 0

            if not time?
                return

            if ir.SessionState >= 5
                element.html 'Finish'
            else
                element.html utils.timeFormat(time, 0, true)

        scope.$watch 'ir.SessionTime', updateSessionTime
        scope.$watch 'ir.SessionState', updateSessionTime

app.directive 'appSessionFlag', (iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData

        updateSessionFlag = ->
            if not ir.SessionFlags
                return
            
            yellowFlag = ((ir.SessionFlags & 0x0000f000) >> (4 * 3)) >= 0x4
            greenFlag = (ir.SessionFlags & 0x0000000f) == 0x4
            checkeredFlag = ir.SessionState >= 5

            element.toggleClass 'yellow-flag', yellowFlag
            element.toggleClass 'green-flag', greenFlag
            element.toggleClass 'checkered-flag', checkeredFlag

            if yellowFlag
                element.html 'Yellow Flag'
            else
                element.html ''

        scope.$watch 'ir.SessionFlags', updateSessionFlag
        scope.$watch 'ir.SessionState', updateSessionFlag

        scope.$watch 'ir.connected', (n, o) ->
            element.removeClass 'yellow-flag green-flag checkered-flag'


angular.bootstrap document, [app.name]
