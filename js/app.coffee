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
            controller: 'SettingsCtrl'
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
        baseUrl = ["http://#{document.location.host}/ir-tvstyleoverlay/","/overlay.html\
            #{if params.length then '#?' + params.join '&' else ''}"]

        $scope.sessionInfoUrl = baseUrl[0] + 'session-info' + baseUrl[1]
        $scope.gapTickerUrl = baseUrl[0] + 'gap-ticker' + baseUrl[1]
        $scope.driverInfoUrl = baseUrl[0] + 'driver-info' + baseUrl[1]
    updateURL()

angular.bootstrap document, [app.name]
