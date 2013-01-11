fs = require "fs-extra"
path = require "path"
snockets = new (require "snockets")()
stylus = require "stylus"
jade = require "jade"
commandRunner = new (require "../utils/commandRunner")()
_ = require "underscore"

# Colors for console.log
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

build = module.exports = (config, done) ->
   
   build.createOutputDirectory(config)

   build.compileViews
      viewDir: config.views.directory
      layouts: config.views.layouts
      output: config.output
   , () ->

      build.buildAssets config.assets, config, () ->
         
         unless config.silent
            ms = (new Date() / 1) - config.start_time
            console.log "#{white}Finished #{green}(#{ms} ms)#{reset}" 
            
         if command = config.run_command
            unless commandSequence = config.commands?[command]
               console.log "#{white}Invalid command: #{red}#{command}#{reset}" unless config.silent
               process.chdir config.starting_directory
               return if done then done()

            console.log "#{white}Running commands: #{command}#{reset} #{green}(#{commandSequence.length})#{white}:#{reset}\n" unless config.silent
            process.chdir config.output
            commandRunner.run commandSequence, config.silent, () ->
               process.chdir config.starting_directory
               done() if done
         else
            process.chdir config.starting_directory
            done() if done

###
options =
   output: output directory
   empty: whether or not to display output logs
###
build.createOutputDirectory = (config) ->
   if fs.existsSync config.output
      if config.empty then build.emptyDirectory config.output
   else
      fs.mkdirsSync config.output

build.emptyDirectory = (dir) ->
   list = fs.readdirSync dir
   ignore = [".git", ".gitignore"]

   for entity in list
      unless path.basename(entity) in ignore 
         fs.removeSync path.join dir, entity

###
options =
   viewDir = Directory of all the views
   layouts = array of filename that should not be compiled 
   output = output directory
###
build.compileViews = (options, done) ->
   assets = build.getViews options
   counter = assets.length
   if counter == 0 then return if done then done()

   for asset in assets
      build.compileAsset.jade asset, viewDir: options.viewDir, (err) ->
         throw err if err
         if --counter <= 0 then done() if done

###
options =
   viewDir = Directory of all the views
   layouts = array of filename that should not be compiled 
   output = output directory
###
build.getViews = (options) ->
   ignoreFiles = [".ds_store"]
   assets = []

   getViewsFromDirectory = (dir) ->
      list = fs.readdirSync dir

      for file in list
         filePath = path.resolve dir, file
         stat = fs.statSync filePath

         # Skip files that should never be copied over (AKA .DS_Store)
         if path.basename(filePath).toLowerCase() in ignoreFiles then continue
         
         if stat and stat.isDirectory()
            getViewsFromDirectory filePath
         else
            asset = build.prepareView filePath, options

            assets.push asset unless asset.is_layout

   getViewsFromDirectory options.viewDir
   return assets

###
options =
   viewDir = Directory of all the views
   layouts = array of filename that should not be compiled 
   output = output directory
###
build.prepareView = (filePath, options) ->
   oldFilename = filePath.replace(options.viewDir, "").replace(/^[\\\/]/g, "")
   asset = {}

   if options.layouts? and (oldFilename in options.layouts)
      asset.is_layout = true

   newName = oldFilename.replace("jade", "html").replace(/[\\\/]/g, "-")

   asset.from = filePath
   asset.to = path.join(options.output, newName)

   build.ensureAssetPathExists(asset)
   
   return asset

###
options =
   debug: in debug mode or not
   output: output directory
###
build.buildAssets = (assets, options, done) ->
   counter = assets.length
   if counter == 0 then return if done then done()
   for asset in assets
      build.buildAsset asset, options, () ->
         if --counter <= 0 then done() if done

###
options =
   debug: in debug mode or not
   output: output directory
###
build.buildAsset = (asset, options, done) ->
   asset = build.prepareAsset asset, options.output
   ext = path.extname(asset.from).replace(".", "")
   compileFn = build.compileAsset[ext] or build.compileAsset["none"]
   compileFn asset, options, (err) ->
      throw err if err
      done() if done

build.compileAsset = 
   ###
   options = (none)
   ###
   none: (asset, options, done) -> fs.copy asset.from, asset.to, done
   
   ###
   options = 
      debug: If true then files are not minified
   ###
   coffee: (asset, options, done) ->
      debug = options?.debug or false
      snockets.getConcatenation asset.from, minify: not debug, (err, js) ->
         throw err if err
         fs.writeFile asset.to, js, done 

   ###
   options =
      viewDir: directory of the views
   ###
   jade: (asset, options, done) ->
      fs.readFile asset.from, (err, data) ->
         throw err if err
         viewDir = options?.viewDir or process.cwd()
         html = jade.compile(data,
            debug: false
            filename: asset.from
         )({settings: {views:viewDir}, filename: asset.from})
         fs.writeFile asset.to, html, done
   
   ###
   options = (none)
   ###
   styl: (asset, options, done) ->
      fs.readFile asset.from, (err, data) ->
         throw err if err

         # Fix paths to imports
         str = build.fixImportPaths(asset, data.toString())

         stylus.render str, {filename: asset.from}, (err, css) ->
            throw err if err
            fs.writeFile asset.to, css, done

build.prepareAsset = (asset, output) ->
   asset = _.clone asset
   asset.from = path.join process.cwd(), asset.from unless asset.from.indexOf(process.cwd()) == 0
   asset.to = asset.to.replace("{out}", output)
   
   build.ensureAssetPathExists(asset)
   return asset

build.ensureAssetPathExists = (asset) ->
   stat = fs.statSync asset.from
   folder = if stat and stat.isDirectory() then asset.to else path.dirname asset.to
   unless fs.existsSync folder then fs.mkdirsSync folder


build.fixImportPaths = (asset, str) ->
   imports = str.match /^@import[/w]*.+$/gm

   for im, i in imports
      str = str.replace /^@import[/w]*.+$/m, "@@import=#{i}"

   for im, i in imports
      filename = im.match(/"(?:[^\\"]+|\\.)*"/)[0].toString().replace(/"/g, "")
      filename = path.join path.dirname(asset.from), filename
      str = str.replace "@@import=#{i}", "@import \"#{filename}\""

   return str

   
