path = require 'path'
{SourceMapConsumer, SourceMapGenerator} = require 'source-map'

module.exports = (grunt) ->

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    coffeelint:
      options:
        no_trailing_whitespace: level: 'error'
        no_empty_param_list: level: 'error'
        no_stand_alone_at: level: 'error'
      src:
        src: 'src/*.coffee'
      test:
        src: 'test/*.coffee'

    coffee:
      options:
        bare: true
        sourceMap: true
      src:
        expand: true
        flatten: false
        src: '*.coffee'
        ext: '.js'
        cwd: 'src'
        dest: 'tmp/src'
      test:
        expand: true
        flatten: false
        src: '*.coffee'
        cwd: 'test'
        ext: '.js'
        dest: 'tmp/test'

    commonjs:
      src:
        prefix: 'src'
        expand: true
        flatten: false
        cwd: 'tmp/src'
        src: '*.js'
        dest: 'tmp/src'
      test:
        prefix: 'test'
        expand: true
        flatten: false
        cwd: 'tmp/test'
        src: '*.js'
        dest: 'tmp/test'

    mapcat:
      src:
        cwd: 'tmp/src'
        src: '*.js'
        dest: 'build/vm.js'
      test:
        cwd: 'tmp/test'
        src: '*.js'
        dest: 'build/test.js'

    watch:
      options:
        nospawn: true
      src:
        files: [
          'src/*.coffee'
          'test/*.coffee'
        ]
        tasks: [
          'coffeelint:changed'
          'coffee:changed'
          'commonjs:changed'
          'mapcat'
          'livereload'
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

  grunt.registerMultiTask 'mapcat', ->
    dest = @data.dest
    sourceMappingURL = "#{path.basename(dest)}.map"
    buffer = []
    lineOffset = 0
    cwd = @data.cwd
    gen = new SourceMapGenerator { file: dest, sourceRoot: '../' }
    @filesSrc.forEach (file) ->
      filepath = path.join cwd, file
      sourceMapPath = filepath + ".map"
      src = grunt.file.read filepath
      src = src.replace(/\/\/@\ssourceMappingURL[^\r\n]*/g, '//')
      buffer.push src
      orig = new SourceMapConsumer grunt.file.read(sourceMapPath)
      orig.eachMapping (m) ->
        gen.addMapping
          generated:
              line: m.generatedLine + lineOffset
              column: m.generatedColumn
          original:
              line: m.originalLine
              column: m.originalColumn
          source: path.join path.dirname(filepath), m.source
      lineOffset += src.split('\n').length
    buffer.push "//@ sourceMappingURL=#{sourceMappingURL}"
    grunt.file.write dest, buffer.join('\n')
    grunt.file.write "#{dest}.map", gen.toString()

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
      wrapped =
        """
        window.require.define({"#{definePath}": function(exports, require, module) {
        #{original}
        }});
        """
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

  grunt.registerTask 'rebuild-debug', ->
    grunt.task.run [
      'clean'
      'coffeelint'
      'coffee'
      'commonjs'
      'mapcat'
    ]

  grunt.registerTask 'default', [
    'rebuild-debug'
    'connect'
    'livereload-start'
    'watch'
  ]

  grunt.event.on 'watch', (action, filepath) ->
    coffeelint = grunt.config.getRaw('coffeelint')
    coffee = grunt.config.getRaw('coffee')
    commonjs = grunt.config.getRaw('commonjs')
    mapcat = grunt.config.getRaw('mapcat')
    livereload = grunt.config.getRaw('livereload')
    if /\.coffee$/.test filepath
      coffeelint.changed = src: filepath
      if /^src/.test filepath
        rel = path.relative coffee.src.cwd, filepath
        coffee.changed =
          expand: true
          flatten: false
          cwd: coffee.src.cwd
          src: path.relative coffee.src.cwd, filepath
          dest: coffee.src.dest
          ext: '.js'
          options:
            bare: true
            sourceMap: true
        commonjs.changed =
          prefix: 'src'
          expand: true
          flatten: false
          cwd: 'tmp/src'
          src: rel.replace /coffee$/, 'js'
          dest: 'tmp/src'
        grunt.regarde = changed: ['vm.js']
      else
        rel = path.relative coffee.test.cwd, filepath
        coffee.changed =
          expand: true
          flatten: false
          cwd: coffee.test.cwd
          src: path.relative coffee.test.cwd, filepath
          dest: coffee.test.dest
          ext: '.js'
          options:
            bare: true
            sourceMap: true
        commonjs.changed =
          prefix: 'test'
          expand: true
          flatten: false
          cwd: 'tmp/test'
          src: rel.replace /coffee$/, 'js'
          dest: 'tmp/test'
        grunt.regarde = changed: ['test.js']
        
