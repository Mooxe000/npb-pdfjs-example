gulp = require 'gulp'

module.exports = ->

  gulp.src 'bower_components/pdfjs-dist/build/*.js'
  .pipe gulp.dest 'build/scripts'

  gulp.src './bower_components/pdfjs-dist/web/**/*'
  .pipe gulp.dest './build/scripts/components'
