module.exports = (grunt) ->
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
        no_implicit_braces: level: 'ignore'
        space_operators: level: 'error'
      src:
        src: 'src/**/*.coffee'
      test:
        src: 'test/**/*.coffee'

    coffee_build:
        options:
          globalAliases: ['Vm']
          src: 'src/**/*.coffee'
          main: 'src/index.coffee'
        browser:
          options:
            dest: 'build/browser/vm.js'
        browser_test:
          options:
            src: 'test/**/*.coffee'
            dest: 'build/browser/test.js'
        nodejs:
          options:
            src: ['src/**/*.coffee', 'test/**/*.coffee']
            dest: 'build/nodejs'

    uglify:
      browser_dist:
        options:
          sourceMap: 'build/browser/vm.min.js.map'
          sourceMapIn: 'build/browser/vm.js.map'
        files:
          'build/browser/vm.min.js': ['build/browser/vm.js']

    mocha_debug:
      options:
        reporter: 'dot'
        check: ['src/**/*.coffee', 'test/**/*.coffee']
      nodejs:
        options:
          src: [
            'build/self.js'
            'test/node_init.js'
            'build/nodejs/**/*.js'
          ]
      browser:
        options:
          phantomjs: true
          phantomTimeout: 30000
          listenAddress: '0.0.0.0'
          src: [
            'build/self.js'
            'node_modules/expect.js/expect.js'
            'build/browser/test.js'
          ]

    watch:
      options:
        nospawn: true
      nodejs:
        files: [
          'src/**/*.coffee'
          'test/**/*.coffee'
        ]
        tasks: [
          'coffeelint:changed'
          'coffee_build'
          'mocha_debug'
        ]

    clean:
      all: ['build']
      nodejs: ['build/nodejs']
      browser: ['build/browser']
      self: ['build/self.js']

  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-coffeelint'
  grunt.loadNpmTasks 'grunt-coffee-build'
  grunt.loadNpmTasks 'grunt-mocha-debug'
  grunt.loadNpmTasks 'grunt-release'

  grunt.registerTask 'self_load', ->
    code = grunt.file.read('./build/browser/vm.js')
    assign = "vmjs = #{JSON.stringify(code)}"
    grunt.file.write('./build/self.js', assign)

  grunt.registerTask 'test', ['mocha_debug']

  grunt.registerTask 'rebuild', [
    'clean:all'
    'coffeelint'
    'coffee_build'
    'self_load'
    'mocha_debug'
    'clean:self'
    'uglify'
  ]

  grunt.registerTask 'debug', [
    'coffeelint'
    'coffee_build'
    'self_load'
    'mocha_debug'
    'watch:nodejs'
  ]

  grunt.registerTask 'publish', ['rebuild', 'release']

  grunt.registerTask 'default', [ 'debug' ]

  grunt.event.on 'watch', (action, filepath) ->
    coffeelint = grunt.config.getRaw('coffeelint')
    if /\.coffee$/.test filepath
      coffeelint.changed = src: filepath
