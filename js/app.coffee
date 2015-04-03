app = angular.module 'gap', [
    'ngRoute'
    'mgcrea.ngStrap.navbar'
    'LocalStorageModule'
    'kutu.markdown'
]

app.config ($routeProvider) ->
    $routeProvider
        .when '/',
            templateUrl: 'tmpl/index.html'
        .when '/settings',
            templateUrl: 'tmpl/settings.html'
            controller: 'SettingsCtrl'
            title: 'Settings'
        .otherwise redirectTo: '/'

app.config (localStorageServiceProvider) ->
    localStorageServiceProvider.setPrefix app.name

app.run ($rootScope, $sce) ->
    $rootScope.$on '$routeChangeSuccess', (event, current, previous) ->
        title = 'TV Style Overlay &middot; iRacing Browser Apps'
        if current.$$route.title?
            title = current.$$route.title + ' &middot; ' + title
        $rootScope.title = $sce.trustAsHtml title

app.service 'iRData', ($rootScope, localStorageService) ->
    settings = localStorageService.get('settings') or {}

    ir = new IRacing \
        # request params
        [
            'SessionNum'
            'IsOnTrack'
        ],
        # request params once
        [
            'DriverInfo'
            'SessionInfo'
            'WeekendInfo'
        ],
        1,
        settings.host or '127.0.0.1:8182'

    ir.onConnect = ->
        ir.data.connected = true
        $rootScope.$apply()

    ir.onDisconnect = ->
        ir.data.connected = false
        $rootScope.$apply()

    ir.onUpdate = (keys) ->
        $rootScope.$apply()

    return ir.data

app.controller 'SettingsCtrl', ($scope, localStorageService) ->
    defaultSettings =
        host: '127.0.0.1:8182'
        fps: 15

    $scope.isDefaultHost = document.location.host == defaultSettings.host

    $scope.settings = settings = localStorageService.get('settings') or {}
    settings.host ?= null
    for p of defaultSettings
        if p not of settings
            settings[p] = defaultSettings[p]

    $scope.saveSettings = saveSettings = ->
        settings.fps = Math.min 60, Math.max(1, settings.fps)
        localStorageService.set 'settings', settings
        updateURL()

    actualKeys = [
        'host'
        'fps'
    ]

    updateURL = ->
        params = []
        for k, v of settings
            if k of defaultSettings and v == defaultSettings[k] then continue
            if v == '' then continue
            if k == 'host' and (not settings.host or $scope.isDefaultHost) then continue
            if k in actualKeys
                params.push "#{k}=#{encodeURIComponent v}"
        $scope.url = "http://#{document.location.host}/ir-tvstyleoverlay/overlay.html\
            #{if params.length then '#?' + params.join '&' else ''}"
    updateURL()

    $scope.changeURL = ->
        params = $scope.url and $scope.url.search(/#\?/) != -1 and $scope.url.split('#?', 2)[1]
        if not params
            return
        for p in params.split '&'
            [k, v] = p.split '=', 2
            if k not of settings
                continue
            nv = Number v
            if not isNaN nv and v.length == nv.toString().length
                v = Number(v)
            settings[k] = v
        saveSettings()

angular.bootstrap document, [app.name]
