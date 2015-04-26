window.app = angular.module 'app', [
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
            updateCarIDs()
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

    updateCarIDs = ->
        for driver in ir.data.DriverInfo.Drivers
            carId = driver.CarID
            ir.data.CarIDs ?= []
            if driver.UserID != -1 and driver.IsSpectator == 0 and carId not in ir.data.CarIDs
                ir.data.CarIDs.push carId

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

app.controller 'GapTickerCtrl', ($scope, $element, config, iRData) ->
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

app.directive 'appGapItem', (iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData
        carIdx = null

        scope.$watch attrs.appGapItem, (n, o) ->
            carIdx = n
            element.toggleClass 'divider', not (carIdx >= 0)

app.directive 'appGapTickerWrapper', ($timeout, iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData

        element.css
            'left': element.parent().prop('offsetWidth') + 'px'

        updateWrapperWidth = ->
            if scope.standings
                wrapperWidth = scope.standings.length * 730
                element.css
                    'width': wrapperWidth + 'px'
                if scope.standings.length <= 3
                    element.css
                        'left': '250px'
                    return
                animateWrapper(wrapperWidth)

        animateWrapper = (wrapperWidth) ->
            # animation speed should always be the same, so subtract gap-items that are already animated to the left
            lengthModifier = 0
            currentLeft = parseInt(element.css('left'))

            if currentLeft <= 0
                lengthModifier = Math.abs(currentLeft / 730)

            Velocity(element, 'stop')
            Velocity(element, {'left': -wrapperWidth + 'px'}, {
                duration: 7000 * (scope.standings.length - lengthModifier),
                easing: 'linear',
                complete: ->
                    if not ir.connected
                        return

                    element.css
                        'left': element.parent().prop('offsetWidth') + 'px'
                    $timeout ->
                        animateWrapper(wrapperWidth)
                    , 100
                })

        scope.$watch 'ir.SessionInfo', updateWrapperWidth
        scope.$watch 'ir.SessionNum', updateWrapperWidth

app.directive 'appOverallPosition', (iRData) ->
    link: (scope, element, attrs) ->
        ir = iRData
        carIdx = null

        scope.$watch attrs.appOverallPosition, (n, o) ->
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
                        element.text '+' + utils.timeFormat gap, 1
                    else if ir.SessionState < 5 and diffLaps > 0 and firstPosition.LastTime != -1 and \
                            Math.ceil(gap / firstPosition.LastTime) == diffLaps
                        element.text "+#{diffLaps - 1} Laps"
                    else if diffLaps > 0
                        element.text "+#{diffLaps} Laps"
                else if diffLaps > 1
                    element.text "+#{diffLaps} Laps"
                else
                    element.text ''
            else
                if gap >= 0
                    element.text '+' + utils.timeFormat gap, 3
                else
                    element.text ''

        scope.$watch 'ir.SessionInfo', updateStandingsGap
        scope.$watch 'ir.SessionNum', updateStandingsGap

angular.bootstrap document, [app.name]
