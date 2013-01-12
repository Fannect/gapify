path = require "path"
_ = require "underscore"

module.exports = (program) ->
   starting_directory = process.cwd()
   if program.chdir then process.chdir(program.chdir)

   defaultOptions = require "../default.json"
   userOptions = require path.join process.cwd(), "gapify.json"

   programOptions = 
      output: program.output or userOptions.output
      cwd: process.cwd()
      empty: program.empty or userOptions.empty
      run_command: program.run or userOptions.default_command
      debug: program.debug or userOptions.debug
      silent: program.silent
      starting_directory: starting_directory
      start_time: new Date() / 1

   config = _.extend defaultOptions, userOptions, programOptions
   config.output = path.resolve process.cwd(), config.output

   if config.views?.directory
      config.views.directory = path.resolve process.cwd(), config.views.directory

   return config