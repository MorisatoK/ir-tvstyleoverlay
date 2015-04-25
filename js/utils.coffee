utils =
    timeFormat: (time, precise = 3, showMins = false) ->
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

    gapFormat: (time) ->
        if time > 1000
            return (time - 1000 | 0) + 'L'
        if time < 1
            return timeFormat time, 2
        timeFormat time, 1

    sessionTimeFormat: (time) ->
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

    shadeColor: (color, percent) ->
        f = parseInt(color.slice(1), 16)
        t = (if percent < 0 then 0 else 255)
        p = (if percent < 0 then percent * -1 else percent)
        R = f >> 16
        G = f >> 8 & 0x00FF
        B = f & 0x0000FF
        '#' + (0x1000000 + (Math.round((t - R) * p) + R) * 0x10000 + (Math.round((t - G) * p) + G) * 0x100 + (Math.round((t - B) * p) + B)).toString(16).slice(1)

    getContrastColor: (hexcolor) ->
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

window.utils = utils