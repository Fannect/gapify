fs = require "fs-extra"
path = require "path"
watcher = require "watch"
build = require "./build"
CommandRunner = require "../utils/commandRunner"
_ = require "underscore"

# Colors for console.log
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

commandRunner = null

watch = module.exports = (config, runner, done) ->
   commandRunner = if runner then runner else new CommandRunner()

   watcher.createMonitor process.cwd(), (monitor) ->
      monitor.on "created", watch.fileChanged
      monitor.on "changed", watch.fileChanged
      
      monitor.on "removed", (file, stat) ->
         asset = watch.getAssociatedAsset(file, config)
         return false unless asset
         fs.removeSync asset.to
         console.log "#{white}Deleted file: #{red}#{path.basename(asset.to)}#{reset}" unless config.silent

watch.fileChanged = (file) ->
   process.chdir config.cwd

   asset = watch.getAssociatedAsset(file, config)
   return false unless asset

   watch.updateAsset asset, config, () ->
      if command = config.run_command
         unless commandSequence = config.commands?[command]
            console.log "#{white}Invalid command: #{red}#{command}#{reset}" unless config.silent
            
         console.log "#{white}Running commands: #{command}#{reset} #{green}(#{commandSequence.length})#{white}:#{reset}\n" unless config.silent
         process.chdir config.output
         commandRunner.run commandSequence, config.silent

watch.getAssociatedAsset = (file, config) ->
   # check assets
   return null if fs.statSync(file).isDirectory()

   for asset in config.assets
      assetPath = path.join process.cwd(), asset.from

      if file == assetPath
         return _.clone asset

      stat = fs.statSync assetPath
      if stat and stat.isDirectory() and file.indexOf(assetPath) == 0
         build.prepareAsset asset, config.output
         
         pathPart = file.replace(asset.from, "")
        
         return {
            from: file
            to: path.join asset.to, pathPart
         }

   # check view directory
   viewPath = config.views.directory

   if file.indexOf(viewPath) == 0
      return build.prepareView file, 
         viewDir: viewPath
         layouts: config.views?.layouts
         ouput: config.output

   return null

watch.updateAsset = (asset, config, done) ->
   if asset.is_layout
      console.log "#{white}Updating all views#{reset}" unless config.silent
      build.compileViews 
         viewDir: path.resolve process.cwd(), config.views.directory
         layouts: config.views.layouts
         output: config.output
      , done
   else
      console.log "#{white}Updating file: #{green}#{path.basename(asset.to)}#{reset}" unless config.silent
      build.buildAsset asset, 
         output: config.output
         viewDir: path.resolve process.cwd(), config.views.directory
      , done



   