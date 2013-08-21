{spawn} = require 'child_process'
path = require 'path'

module.exports = (grunt) ->
  data =
    # map used to store files with the debugger statement
    # used to automatically turn debugging on/off
    debug: null
    # current test runner process
    child: null

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    coffeelint:
      options:
        arrow_spacing: level: 'error'
        empty_constructor_needs_parens: level: 'error'
        non_empty_constructor_needs_parens: level: 'error'
        no_trailing_whitespace: level: 'error'
        no_empty_param_list: level: 'error'
        no_stand_alone_at: level: 'error'
        no_backticks: level: 'ignore'
        no_implicit_braces: level: 'error'
        space_operators: level: 'error'
      src:
        src: 'src/**/*.coffee'
      test:
        src: 'test/**/*.coffee'

    coffee_build:
        options:
          wrap: true
          sourceMap: true
          disableModuleWrap: [
            'node_modules/esprima/esprima.js'
            'platform/browser_export.coffee'
          ]
          disableSourceMap: ['node_modules/esprima/esprima.js']
        browser:
          files: [{
            src: [
              'node_modules/esprima/esprima.js'
              'src/**/*.coffee'
              'platform/browser_export.coffee'
            ]
            dest: 'build/browser/vm.js'
          }, {
            src: [
              'node_modules/esprima/esprima.js'
              'test/**/*.coffee'
            ]
            dest: 'build/browser/test.js'
          }]
        nodejs:
          options:
            disableModuleWrap: [
              'platform/node_init.coffee'
              'platform/node_export.coffee'
            ]
          files: [{
            src: [
              'platform/node_init.coffee'
              'src/**/*.coffee'
              'platform/node_export.coffee'
            ]
            dest: 'build/node/vm.js'
          }, {
            src: [
              'platform/node_init.coffee'
              'test/**/*.coffee'
            ]
            dest: 'build/node/test.js'
          }]

    check_debug:
      all: [
        'platform/**/*.js'
        'platform/**/*.coffee'
        'src/**/*.coffee'
        'test/**/*.coffee'
        'src/**/*.js'
        'test/**/*.js'
      ]

    test:
      all: [
        'test/index.js'
        'build/node/test.js'
      ]

    watch:
      options:
        nospawn: true
      browser:
        files: [
          'src/**/*.coffee'
          'test/**/*.coffee'
        ]
        tasks: [
          'coffeelint:changed'
          'coffee_build:browser'
          'livereload'
        ]
      nodejs:
        files: [
          'src/**/*.coffee'
          'test/**/*.coffee'
        ]
        tasks: [
          'coffeelint:changed'
          'coffee_build:nodejs'
          'check_debug:changed'
          'test'
        ]

    connect:
      options:
        hostname: '0.0.0.0'
        middleware: (connect, options) -> [
          connect.static(options.base)
          connect.directory(options.base)
        ]
      project:
        options:
          port: 8000
          base: './'

    clean:
      node:
        ['build/node']
      browser:
        ['build/browser']

  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-livereload'
  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-coffeelint'
  grunt.loadNpmTasks 'grunt-coffee-build'

  grunt.registerMultiTask 'check_debug', ->
    data.debug = {}
    files = @filesSrc
    for file in files
      code = grunt.file.read(file)
      if /^\s*debugger\s*/gm.test(code)
        data.debug[file] = true
      else delete data.debug[file]

  grunt.registerMultiTask 'test', ->
    done = @async()
    args = @filesSrc
    args.unshift('--check-leaks')
    if data.debug and Object.keys(data.debug).length
      args.unshift('--debug-brk')
    opts = stdio: 'inherit'
    data.child = spawn('./node_modules/.bin/mocha', args, opts)
    data.child.on 'close', (code) ->
      data.child = null
      done(code is 0)

  grunt.registerTask 'common-rebuild', ->
    grunt.task.run [
      'connect'
      'coffeelint'
    ]

  grunt.registerTask 'debug-browser', ->
    grunt.task.run [
      'clean:browser'
      'livereload-start'
      'common-rebuild'
      'coffee_build:browser'
      'watch:browser'
    ]

  grunt.registerTask 'debug-nodejs', ->
    grunt.task.run [
      'clean:node'
      'common-rebuild'
      'coffee_build:nodejs'
      'check_debug'
      'test'
      'watch:nodejs'
    ]

  grunt.registerTask 'default', [
    'debug-nodejs'
  ]

  grunt.event.on 'watch', (action, filepath) ->
    coffeelint = grunt.config.getRaw('coffeelint')
    checkDebug = grunt.config.getRaw('check_debug')
    if /\.coffee$/.test filepath
      checkDebug.changed = [filepath]
      coffeelint.changed = src: filepath
      grunt.regarde = changed: ['test.js']
      if data.child
        data.child.kill('SIGTERM')
