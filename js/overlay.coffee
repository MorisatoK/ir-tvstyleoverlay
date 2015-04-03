window.app = angular.module 'app', [
    'ngAnimate'
    'ngSanitize'
]

app.service 'config', ($location) ->
    vars = $location.search()

    fps = parseInt(vars.fps) or 10
    fps = Math.max 1, Math.min 60, fps

    host: vars.host or '127.0.0.1:8182'
    fps: fps

app.service 'iRData', ($rootScope, config) ->
    requestParams = [
        # yaml
        'DriverInfo'
        'SessionInfo'

        # telemetry
        'CamCarIdx'
        #'CarIdxGear'
        #'CarIdxLap'
        #'CarIdxLapDistPct'
        'CarIdxOnPitRoad'
        #'CarIdxRPM'
        'CarIdxTrackSurface'
        #'FuelLevel'
        #'Gear'
        #'IsOnTrack'
        #'IsOnTrackCar'
        #'IsReplayPlaying'
        #'Lap'
        #'LapDist'
        #'LapDistPct'
        #'OilTemp'
        #'OnPitRoad'
        #'RadioTransmitCarIdx'
        #'ReplayFrameNum'
        #'ReplayFrameNumEnd'
        #'RPM'
        #'SessionFlags'
        'SessionNum'
        'SessionState'
        'SessionTime'
        'SessionTimeRemain'
        # 'Speed'
        #'WaterTemp'
    ]

    ir = new IRacing \
        # request params
        requestParams,
        # request params once
        [
            'QualifyResultsInfo'
            'WeekendInfo'
        ],
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
        if 'DriverInfo' in keys
            updateDriversByCarIdx()
            updateCarClassIDs()
        if 'SessionInfo' in keys
            updatePositionsByCarIdx()
        if 'QualifyResultsInfo' in keys
            updateQualifyResultsByCarIdx()
        $rootScope.$apply()

    updateDriversByCarIdx = ->
        ir.data.myCarIdx = ir.data.DriverInfo.DriverCarIdx
        ir.data.DriversByCarIdx ?= {}
        for driver in ir.data.DriverInfo.Drivers
            ir.data.DriversByCarIdx[driver.CarIdx] = driver

    updateCarClassIDs = ->
        for driver in ir.data.DriverInfo.Drivers
            carClassId = driver.CarClassID
            ir.data.CarClassIDs ?= []
            if driver.UserID != -1 and driver.IsSpectator == 0 and carClassId not in ir.data.CarClassIDs
                ir.data.CarClassIDs.push carClassId

    updatePositionsByCarIdx = ->
        ir.data.PositionsByCarIdx ?= []
        for session, i in ir.data.SessionInfo.Sessions
            while i >= ir.data.PositionsByCarIdx.length
                ir.data.PositionsByCarIdx.push {}
            if session.ResultsPositions
                for position in session.ResultsPositions
                    ir.data.PositionsByCarIdx[i][position.CarIdx] = position

    updateQualifyResultsByCarIdx = ->
        ir.data.QualifyResultsByCarIdx ?= {}
        for position in ir.data.QualifyResultsInfo.Results
            ir.data.QualifyResultsByCarIdx[position.CarIdx] = position

    return ir.data

###########
### GAP ###
###########

app.controller 'GapCtrl', ($scope, $element, config, iRData) ->
    ir = $scope.ir = iRData
    carIdx = null

    $scope.$watch 'ir.connected', (n, o) ->
        $element.toggleClass 'ng-hide', not n

    updateStandings = ->
        if not ir.SessionInfo or not (ir.SessionNum >= 0)
            return
        session = ir.SessionInfo.Sessions[ir.SessionNum]
        standings = session.ResultsPositions or []
        if not standings.length and ir.QualifyResultsInfo
            $scope.standingsType = 'QualifyResults'
            standings = ir.QualifyResultsInfo.Results
        else
            $scope.standingsType = session.SessionType

        $scope.standingsOriginal = standings.slice()
        $scope.standings = standings

    $scope.$watch 'ir.SessionInfo', updateStandings
    $scope.$watch 'ir.SessionNum', updateStandings
    $scope.$watch 'ir.QualifyResultsInfo', updateStandings

app.directive 'appGapItem', ($animate, $timeout, config, iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData
        carIdx = null

        scope.$watch attrs.appGapItem, (n, o) ->
            carIdx = n
            element.toggleClass 'divider', not (carIdx >= 0)

app.directive 'appGapWrapper', ($timeout, iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData

        element.css
            'left': element.parent().width()

        updateWrapperWidth = ->
            if scope.standings
                wrapperWidth = scope.standings.length * 600
                element.css
                    'width': wrapperWidth + 'px'
                if scope.standings.length <= 3
                    element.css
                        'left': '170px'
                    return
                animateWrapper(wrapperWidth)

        animateWrapper = (wrapperWidth) ->
            # animation speed should always be the same, so subtract gap-items that are already animated to the left
            lengthModifier = 0
            currentLeft = parseInt(element.css('left'))

            if currentLeft <= 0
                lengthModifier = Math.abs(currentLeft / 600)

            element.velocity('stop').velocity({'left': -wrapperWidth + 'px'}, {
                duration: 2000 * (scope.standings.length - lengthModifier),
                easing: 'linear',
                complete: ->
                    if not ir.connected
                        return

                    element.css {'left': element.parent().width()}
                    $timeout ->
                        animateWrapper(wrapperWidth)
                    , 100
                })

        scope.$watch 'ir.SessionInfo', updateWrapperWidth
        scope.$watch 'ir.SessionNum', updateWrapperWidth

app.directive 'appStandingsPosition', (config, iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData
        carIdx = null

        scope.$watch attrs.appStandingsPosition, (n, o) ->
            carIdx = n
            updateStandingsPosition()

        updateStandingsPosition = ->
            if not carIdx?
                return
            isQualifyResults = scope.$parent.standingsType == 'QualifyResults'
            position = scope.i
            pos = position.Position
            if isQualifyResults
                pos += 1
            element.text pos

        scope.$watch 'ir.SessionInfo', updateStandingsPosition
        scope.$watch 'ir.SessionNum', updateStandingsPosition

app.directive 'appCarNumber', (iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData
        carIdx = null

        scope.$watch attrs.appCarNumber, (n, o) ->
            carIdx = n
            updateCarNumber()

        updateCarNumber = ->
            if not carIdx? or not ir.DriversByCarIdx? or carIdx not of ir.DriversByCarIdx
                element.text ''
                return
            driver = ir.DriversByCarIdx[carIdx]
            carClassColor = driver.CarClassColor
            if carClassColor == 0xffffff
                carClassColor = 0xffda59
            if carClassColor == 0
                carClassId = driver.CarClassID
                for d in ir.DriverInfo.Drivers
                    if d.CarClassID == carClassId and d.CarClassColor
                        carClassColor = d.CarClassColor

            element.text "#{driver.CarNumber}"
            element.append '<span class="car-class" />'
            element.children().css
                background: "rgba(#{carClassColor >> 16},\
                    #{carClassColor >> 8 & 0xff},\
                    #{carClassColor & 0xff},\
                    1)"

        scope.$watch 'ir.DriverInfo', updateCarNumber

app.directive 'appGapTime', (iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData
        carIdx = null

        scope.$watch attrs.appGapTime, (n, o) ->
            carIdx = n
            updateStandingsGap()

        updateStandingsGap = ->
            if not carIdx? or not ir.SessionInfo
                element.addClass 'ng-hide'
                return

            standings = scope.$parent.standingsOriginal
            standingsType = scope.$parent.standingsType
            isRace = standingsType == 'Race'
            firstPosition = standings[0]
            position = scope.i

            element.toggleClass 'ng-hide', isRace and firstPosition.LapsComplete == 0

            if firstPosition.CarIdx == carIdx
                element.text if isRace then position.LapsComplete + ' Laps' else ''
                return

            if isRace
                gap = position.Time - firstPosition.Time
            else
                gap = if position.FastestTime > 0 then position.FastestTime - firstPosition.FastestTime else -1

            if isRace
                diffLaps = firstPosition.LapsComplete - position.LapsComplete
                if gap >= 0 and position.LapsComplete
                    if diffLaps <= 0 or \
                            (diffLaps == 1 and (firstPosition.LastTime == -1 or gap < firstPosition.LastTime))
                        element.text '+' + timeFormat gap, 1
                    else if ir.SessionState < 5 and diffLaps > 0 and firstPosition.LastTime != -1 and \
                            Math.ceil(gap / firstPosition.LastTime) == diffLaps
                        element.text "+#{diffLaps - 1}L"
                    else if diffLaps > 0
                        element.text "+#{diffLaps}L"
                else if diffLaps > 1
                    element.text "+#{diffLaps}L"
                else
                    element.text ''
            else
                if gap >= 0
                    element.text '+' + timeFormat gap, 3
                else
                    element.text ''

        scope.$watch 'ir.SessionInfo', updateStandingsGap
        scope.$watch 'ir.SessionNum', updateStandingsGap

app.directive 'appIntTime', (iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData
        carIdx = null

        scope.$watch attrs.appIntTime, (n, o) ->
            carIdx = n
            updateStandingsInt()

        updateStandingsInt = ->
            carIdx = scope.$eval attrs.appIntTime
            if not carIdx? or not ir.SessionInfo
                element.addClass 'ng-hide'
                return
            standings = scope.$parent.standingsOriginal
            standingsType = scope.$parent.standingsType
            isRace = standingsType == 'Race'
            firstPosition = standings[0]
            position = scope.i

            element.toggleClass 'ng-hide', isRace and firstPosition.LapsComplete == 0

            if firstPosition.CarIdx == carIdx
                element.text ''
                return

            prevPosition = standings[standings.indexOf(position) - 1]
            if isRace
                interval = position.Time - prevPosition.Time
            else
                interval = if position.FastestTime > 0 and prevPosition.FastestTime > 0 \
                    then position.FastestTime - prevPosition.FastestTime else -1

            if isRace
                diffLaps = prevPosition.LapsComplete - position.LapsComplete
                if interval >= 0 and position.LapsComplete
                    if diffLaps <= 0 or \
                            (diffLaps == 1 and (firstPosition.LastTime == -1 or interval < firstPosition.LastTime))
                        element.text '+' + timeFormat interval, 1
                    else if ir.SessionState < 5 and diffLaps > 0 and firstPosition.LastTime != -1 and \
                            Math.ceil(interval / firstPosition.LastTime) == diffLaps
                        element.text "+#{diffLaps - 1}L"
                    else if diffLaps > 0
                        element.text "+#{diffLaps}L"
                else if diffLaps > 1
                    element.text "+#{diffLaps}L"
                else
                    element.text ''
            else
                if interval >= 0
                    element.text '+' + timeFormat interval, 3
                else
                    element.text ''

        scope.$watch 'ir.SessionInfo', updateStandingsInt
        scope.$watch 'ir.SessionNum', updateStandingsInt

###############
### SESSION ###
###############

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

            element.html timeFormat(time, 0, true)

        scope.$watch 'ir.SessionTime', updateSessionTime

###########
### Car ###
###########

app.controller 'CarCtrl', ($scope, $element, config, iRData) ->
    ir = $scope.ir = iRData

    $scope.$watch 'ir.CamCarIdx', (n, o) ->
        $element.addClass 'ng-hide'

        if not ir.SessionInfo
            return

        if ir.CamCarIdx > 0 \
            and ir.DriversByCarIdx[ir.CamCarIdx].IsSpectator == 0 \
            and ir.CarIdxTrackSurface[ir.CamCarIdx] > -1
                $element.removeClass 'ng-hide'

    $scope.$watch 'ir.connected', (n, o) ->
        $element.toggleClass 'ng-hide', not n

app.directive 'appClassPosition', (config, iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData

        scope.$watch attrs.appClassPosition, (n, o) ->
            updateClassPosition()

        updateClassPosition = ->
            if not ir.PositionsByCarIdx or not ir.PositionsByCarIdx[ir.SessionNum]
                return

            if not ir.CarClassIDs or ir.CarClassIDs.length < 2 or not ir.DriversByCarIdx or ir.DriversByCarIdx[ir.CamCarIdx].IsSpectator or ir.CamCarIdx == 0
                return

            driver = ir.DriversByCarIdx[ir.CamCarIdx]
            carClassColor = driver.CarClassColor
            if carClassColor == 0xffffff
                carClassColor = 0xffda59
            if carClassColor == 0
                carClassId = driver.CarClassID
                for d in ir.DriverInfo.Drivers
                    if d.CarClassID == carClassId and d.CarClassColor
                        carClassColor = d.CarClassColor
            carClassColor = '#' + carClassColor.toString(16)

            element.text ir.PositionsByCarIdx[ir.SessionNum][ir.CamCarIdx].ClassPosition + 1
            element.wrapInner '<span class="text" />'
            element.css
                background: 'linear-gradient(to bottom, ' + shadeColor(carClassColor, 0.3) + ' 0%, ' + shadeColor(carClassColor, -0.1) + ' 100%)'

            if getContrastColor(carClassColor) == 'black'
                element.children().css
                    'text-shadow': 'rgba(0, 0, 0, 1) 0px 0px 15px'


        scope.$watch 'ir.SessionInfo', updateClassPosition
        scope.$watch 'ir.SessionNum', updateClassPosition

app.directive 'appOverallPosition', (config, iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData

        scope.$watch attrs.appOverallPosition, (n, o) ->
            updateOverallPosition()

        updateOverallPosition = ->
            if not ir.PositionsByCarIdx or not ir.PositionsByCarIdx[ir.SessionNum] or not ir.PositionsByCarIdx[ir.SessionNum][ir.CamCarIdx]
                return

            if not ir.DriversByCarIdx or ir.DriversByCarIdx[ir.CamCarIdx].IsSpectator or ir.CamCarIdx == 0
                return

            element.text ir.PositionsByCarIdx[ir.SessionNum][ir.CamCarIdx].Position
            element.wrapInner '<span class="text" />'

        scope.$watch 'ir.SessionInfo', updateOverallPosition
        scope.$watch 'ir.SessionNum', updateOverallPosition

app.filter 'time', -> timeFormat
app.filter 'gap', -> gapFormat

angular.bootstrap document, [app.name]

#############
### UTILS ###
#############

timeFormat = (time, precise = 3, showMins = false) ->
    sign = time >= 0
    time = Math.abs time

    if precise > 0
        precisePow = [10, 100, 1000][precise - 1]
        time = Math.round(time * precisePow) / precisePow
    else
        time = Math.round(time)

    h = time / 3600 | 0
    m = (time / 60 | 0) % 60
    s = time % 60
    res = ''

    if h
        res += "#{h}:"
        if m < 10 then m = "0#{m}"
    if m or showMins
        res += "#{m}:"
        if s < 10
            res += "0#{s.toFixed precise}"
        else
            res += s.toFixed precise
    else
        res += s.toFixed precise

    if not sign
        res = "-#{res}"

    res

gapFormat = (time) ->
    if time > 1000
        return (time - 1000 | 0) + 'L'
    if time < 1
        return timeFormat time, 2
    timeFormat time, 1

sessionTimeFormat = (time) ->
    h = time / 3600 | 0
    m = (time / 60 | 0) % 60
    res = ''
    if h
        res += "#{h}h"
    if m
        if h and m < 10
            res += "0#{m}m"
        else
            res += "#{m}m"
    res

shadeColor = (color, percent) ->
    f = parseInt(color.slice(1), 16)
    t = (if percent < 0 then 0 else 255)
    p = (if percent < 0 then percent * -1 else percent)
    R = f >> 16
    G = f >> 8 & 0x00FF
    B = f & 0x0000FF
    '#' + (0x1000000 + (Math.round((t - R) * p) + R) * 0x10000 + (Math.round((t - G) * p) + G) * 0x100 + (Math.round((t - B) * p) + B)).toString(16).slice(1)

getContrastColor = (hexcolor) ->
    if hexcolor.indexOf '#' > -1
        hexcolor = hexcolor.slice(1)
    r = parseInt(hexcolor.substr(0,2), 16)
    g = parseInt(hexcolor.substr(2,2), 16)
    b = parseInt(hexcolor.substr(4,2), 16)
    yiq = ((r*299) + (g*587) + (b*114)) / 1000
    color = ''
    if (yiq >= 128)
        color = 'black'
    else
        color = 'white'
    color
