echo = console.log
browserSync = require 'browser-sync'

url = require 'url'
proxy = require 'proxy-middleware'
modRewrite  = require 'connect-modrewrite'

module.exports = ->

  proxyOptions = url.parse 'http://localhost:9000/'
  proxyOptions.route = '/npb-pdfjs-example'

  browserSync
    server:
      baseDir: './build'
      index: 'index.html'
      middleware: [
        proxy proxyOptions
      ]
    port: 9000
    startPath: '/'
    watchTask: true
