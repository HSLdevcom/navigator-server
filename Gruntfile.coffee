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

    watch:
      files: [
        'Gruntfile.coffee'
        'src/*.coffee'
      ]
      tasks: 'default'

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'

  grunt.registerTask 'start-server', 'Start the server', ->
    bayeux = require './lib/server.js'
    bayeux.listen 9002

  grunt.registerTask 'default', ['coffee']
  grunt.registerTask 'server', ['coffee', 'start-server', 'watch']
