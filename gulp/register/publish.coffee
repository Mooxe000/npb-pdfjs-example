gulp   = require 'gulp'
publish = require 'gulp-gh-pages'

module.exports = ->

  gulp.src './build/**/*'
  .pipe publish()
