{spawn} = require 'child_process'
path = require 'path'
{SourceMapConsumer, SourceMapGenerator} = require 'source-map'

module.exports = (grunt) ->
  # load some browser dependencies
  commonjs = grunt.file.read('./app/components/commonjs/common.js')
  esprima = grunt.file.read('./node_modules/esprima/esprima.js')
  esprima = commonjsWrap('esprima', esprima)

  data =
    # map used to store files with the debugger statement
    # used to automatically turn debugging on/off
    debug: null
    # current test runner process
    child: null

  coffeeOpts = (prefix, src = '**/*.coffee') ->
    expand: true
    flatten: false
    src: src
    ext: '.js'
    cwd: prefix
    dest: "tmp/#{prefix}"

  commonjsOpts = (prefix, src = '**/*.js') ->
    expand: true
    flatten: false
    prefix: prefix
    cwd: "tmp/#{prefix}"
    src: src
    dest: "tmp/#{prefix}"

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    coffeelint:
      options:
        no_trailing_whitespace: level: 'error'
        no_empty_param_list: level: 'error'
        no_stand_alone_at: level: 'error'
        no_backticks: level: 'ignore'
      src:
        src: 'src/**/*.coffee'
      test:
        src: 'test/**/*.coffee'

    coffee:
      options:
        bare: true
        sourceMap: true
      src: coffeeOpts('src')
      test: coffeeOpts('test')

    commonjs:
      src: commonjsOpts('src')
      test: commonjsOpts('test')

    mapcat:
      all:
        prepend:
          """
          (function(global) {
          var window; // undefine window so commonjs will be contained
          #{commonjs}
          #{esprima}
          """.split('\n')
        append: ['})(window.vm = {});']
        cwd: 'tmp'
        src: '**/*.js'
        dest: 'build/vm.js'

    'check-debug':
      all: [
        'src/**/*.coffee'
        'test/**/*.coffee'
      ]

    test:
      all: [
        'test/index.js'
        'tmp/test/**/*.js'
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
          'common-changed'
          'commonjs:changed'
          'mapcat'
          'livereload'
        ]
      nodejs:
        files: [
          'src/**/*.coffee'
          'test/**/*.coffee'
        ]
        tasks: [
          'common-changed'
          'check-debug:changed'
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

    clean: ['build', 'tmp']

  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-livereload'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-coffeelint'

  grunt.registerMultiTask 'check-debug', ->
    data.debug = {}
    files = @filesSrc
    for file in files
      code = grunt.file.read(file)
      if /^\s*debugger\s*/gm.test(code) then data.debug[file] = true
      else delete data.debug[file]

  grunt.registerMultiTask 'test', ->
    done = @async()
    args = @filesSrc
    args.unshift('--check-leaks')
    if Object.keys(data.debug).length then args.unshift('--debug-brk')
    opts = stdio: 'inherit'
    data.child = spawn('./node_modules/.bin/mocha', args, opts)
    data.child.on 'close', (code) ->
      data.child = null
      done(code == 0)

  grunt.registerMultiTask 'mapcat', ->
    dest = @data.dest
    sourceMappingURL = "#{path.basename(dest)}.map"
    buffer = @data.prepend || []
    lineOffset = buffer.length
    cwd = @data.cwd
    gen = new SourceMapGenerator { file: dest, sourceRoot: '../' }
    @filesSrc.forEach (file) ->
      filepath = path.join(cwd, file)
      sourceMapPath = filepath + ".map"
      src = grunt.file.read(filepath)
      src = src.replace(/\/\/@\ssourceMappingURL[^\r\n]*/g, '//')
      buffer = buffer.concat(src.split('\n'))
      orig = new SourceMapConsumer grunt.file.read(sourceMapPath)
      orig.eachMapping (m) ->
        gen.addMapping
          generated:
              line: m.generatedLine + lineOffset
              column: m.generatedColumn
          original:
              line: m.originalLine
              column: m.originalColumn
          source: path.join(path.dirname(filepath), m.source)
      lineOffset = buffer.length
    if @data.prepend
      buffer = buffer.concat(@data.append)
    buffer.push("//@ sourceMappingURL=#{sourceMappingURL}")
    grunt.file.write(dest, buffer.join('\n'))
    grunt.file.write("#{dest}.map", gen.toString())

  grunt.registerMultiTask 'commonjs', ->
    prefix = @data.prefix
    # wraps each file into a commonjs module while adjusting the source map
    @files.forEach (file) ->
      lead = new RegExp("^#{file.orig.cwd}/")
      filepath = file.src[0]
      original = grunt.file.read filepath
      definePath = filepath.replace lead, ''
      definePath = definePath.replace /\.js$/, ''
      definePath = "#{prefix}/#{definePath}"
      wrapped = commonjsWrap(definePath, original)
      grunt.file.write(filepath, wrapped)
      sourceMapPath = filepath + ".map"
      if not grunt.file.exists(sourceMapPath)
        return
      map = new SourceMapConsumer grunt.file.read(sourceMapPath)
      gen = new SourceMapGenerator
        file: map.file
      map.eachMapping (m) ->
        gen.addMapping
          generated: {line: m.generatedLine + 1, column: m.generatedColumn}
          original: {line: m.originalLine, column: m.originalColumn}
          source: m.source
      grunt.file.write(sourceMapPath, gen.toString())

  grunt.registerTask 'common-changed', ->
    grunt.task.run [
      'coffeelint:changed'
      'coffee:changed'
    ]

  grunt.registerTask 'common-rebuild', ->
    grunt.task.run [
      'clean'
      'connect'
      'coffeelint'
      'coffee'
    ]

  grunt.registerTask 'debug-browser', ->
    grunt.task.run [
      'livereload-start'
      'common-rebuild'
      'commonjs'
      'mapcat'
      'watch:browser'
    ]

  grunt.registerTask 'debug-nodejs', ->
    grunt.task.run [
      'common-rebuild'
      'check-debug'
      'test'
      'watch:nodejs'
    ]

  grunt.registerTask 'default', [
    'debug-nodejs'
  ]

  grunt.event.on 'watch', (action, filepath) ->
    changed = (prefix) ->
      code = grunt.file.read(filepath)
      rel = path.relative(coffee[prefix].cwd, filepath)
      coffee.changed = coffeeOpts(prefix, rel)
      commonjs.changed = commonjsOpts(prefix, rel.replace(/coffee$/, 'js'))

    coffeelint = grunt.config.getRaw('coffeelint')
    coffee = grunt.config.getRaw('coffee')
    commonjs = grunt.config.getRaw('commonjs')
    checkDebug = grunt.config.getRaw('check-debug')
    if /\.coffee$/.test filepath
      checkDebug.changed = [filepath]
      coffeelint.changed = src: filepath
      grunt.regarde = changed: ['test.js']
      if /^src/.test filepath then changed('src')
      else changed('test')
      if data.child
        data.child.kill('SIGTERM')


commonjsWrap = (definePath, code) ->
  """
  global.require.define({"#{definePath}": function(exports, require, module) {
  #{code}
  }});
  """
