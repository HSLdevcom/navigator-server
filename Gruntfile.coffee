module.exports = (grunt) ->
  grunt.initConfig
    pkg: '<json:package.json>'

    coffee:
      lib:
        expand: true
        cwd: 'src'
        src: ['*.coffee']
        dest: 'lib/'
        ext: '.js'

    copy:
      main:
        expand: true
        cwd: 'data'
        src: ['*']
        dest: 'lib/data/'

    watch:
      files: [
        'Gruntfile.coffee'
        'src/*.coffee'
      ]
      tasks: 'default'

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-copy'

  grunt.registerTask 'start-server', 'Start the server', ->
    bayeux = require './lib/server.js'
    bayeux.listen 9002

  grunt.registerTask 'default', ['coffee', 'copy']
  grunt.registerTask 'server', ['coffee', 'copy','start-server', 'watch']
