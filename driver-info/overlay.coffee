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
        #'CarIdxOnPitRoad'
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
        #'SessionState'
        #'SessionTime'
        #'SessionTimeRemain'
        # 'Speed'
        #'WaterTemp'
    ]

    ir = new IRacing \
        # request params
        requestParams,
        # request params once
        [
            #'QualifyResultsInfo'
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

    return ir.data

app.controller 'DriverInfoCtrl', ($scope, $element, config, iRData) ->
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
            carClassColor = utils.getCarClassColor(driver.CarClassColor, driver, ir.DriverInfo.Drivers)

            element.text ir.PositionsByCarIdx[ir.SessionNum][ir.CamCarIdx].ClassPosition + 1
            element.css
                background: 'linear-gradient(to bottom, ' + utils.shadeColor(carClassColor, 0.3) + ' 0%, ' + utils.shadeColor(carClassColor, -0.1) + ' 100%)'

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

        scope.$watch 'ir.SessionInfo', updateOverallPosition
        scope.$watch 'ir.SessionNum', updateOverallPosition

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
            carClassColor = utils.getCarClassColor(driver.CarClassColor, driver, ir.DriverInfo.Drivers)

            element.text "#{driver.CarNumber}"
            element.append '<span class="car-class" />'
            element.children().css
                background: 'linear-gradient(to bottom, ' + utils.shadeColor(carClassColor, 0.3) + ' 0%, ' + utils.shadeColor(carClassColor, -0.1) + ' 100%)'

        scope.$watch 'ir.DriverInfo', updateCarNumber

angular.bootstrap document, [app.name]
