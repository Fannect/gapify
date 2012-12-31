fs = require "fs-extra"
path = require "path"
_ = require "underscore"
snockets = new (require "snockets")()
stylus = require "stylus"
jade = require "jade"
async = require "async"
exec = require('child_process').exec

# Colors for console.log
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

mod = module.exports = (program, done) ->
   originalDir = process.cwd()
   startTime = new Date() / 1

   mod.changeWorkingDirectory(program.chdir)
   config = mod.loadConfig()
   outDir = path.join process.cwd(), program.output or config.output 
   
   mod.createOutputDirectory(outDir, program.empty or false)
   mod.compileViews config.views, outDir
   mod.copyAssets config.assets, program.debug or false, outDir, () ->
      
      unless program.silent
         ms = (new Date() / 1) - startTime
         console.log "#{white}Finished #{green}(#{ms} ms)#{reset}" 
         
      if config.on_success && config.on_success?.length > 0
         console.log "#{white}Starting commands#{reset} #{green}(#{config.on_success.length})#{white}:#{reset}\n"
         mod.changeWorkingDirectory outDir
         mod.runCommands config.on_success, program.silent, () ->
            mod.changeWorkingDirectory originalDir
            done() if done
      else
         done() if done

mod.changeWorkingDirectory = (dir) ->
   if dir then process.chdir dir
      
mod.loadConfig = () ->
   defaultOptions = require "../default.json"
   userOptions = require path.join process.cwd(), "gapify.json"
   return _.extend defaultOptions, userOptions

mod.createOutputDirectory = (dir, empty) ->
   if fs.existsSync dir
      if empty then mod.emptyDirectory dir
   else
      fs.mkdirsSync dir

mod.emptyDirectory = (dir) ->
   list = fs.readdirSync dir
   ignore = [".git", ".gitignore"]

   for entity in list
      unless path.basename(entity) in ignore 
         fs.removeSync path.join dir, entity

mod.compileViews = (config, outDir) ->
   viewDir = path.join process.cwd(), config.directory
   compileViewDirectory = (dir) ->
      list = fs.readdirSync dir

      for file in list
         filePath = path.resolve dir, file
         stat = fs.statSync filePath

         if stat and stat.isDirectory()
            compileViewDirectory filePath
         else
            oldFilename = filePath.replace(viewDir, "").replace(/^[\\\/]/g, "")
            unless oldFilename in config.ignore
               filename = oldFilename.replace("jade", "html").replace(/[\\\/]/g, "-")
               contents = fs.readFileSync filePath
               html = jade.compile(contents,
                  debug: false
                  filename: filePath
               )({settings: {views:viewDir}, filename: filePath})
               fs.writeFileSync path.join(outDir, filename), html

   compileViewDirectory viewDir

mod.copyAssets = (assets, debug, outDir, done) ->
   counter = assets.length
   if counter == 0 then done() if done
   for asset in assets
      asset.from = path.join process.cwd(), asset.from
      asset.to = asset.to.replace("{out}", outDir)
      
      # Ensure directory exists
      stat = fs.statSync asset.from
      folder = if stat and stat.isDirectory() then asset.to else path.dirname asset.to
      unless fs.existsSync folder then fs.mkdirsSync folder

      # Compile assets
      ext = path.extname(asset.from).replace(".", "")
      compileFn = mod.compileAsset[ext] or mod.compileAsset["none"]
      compileFn asset, debug, (err) ->
         throw err if err
         if --counter <= 0 then done() if done

mod.compileAsset = 
   none: (asset, debug, done) -> fs.copy asset.from, asset.to, done
   coffee: (asset, debug, done) ->
      snockets.getConcatenation asset.from, minify: !debug, (err, js) ->
         throw err if err
         fs.writeFile asset.to, js, done 
   styl: (asset, debug, done) ->
      fs.readFile asset.from, (err, data) ->
         throw err if err

         # Fix paths to imports
         str = mod.fixImportPaths(asset, data.toString())

         stylus.render str, {filename: asset.from}, (err, css) ->
            throw err if err
            fs.writeFile asset.to, css, done

mod.fixImportPaths = (asset, str) ->
   imports = str.match /^@import[/w]*.+$/gm

   for im, i in imports
      str = str.replace /^@import[/w]*.+$/m, "@@import=#{i}"

   for im, i in imports
      filename = im.match(/"(?:[^\\"]+|\\.)*"/)[0].toString().replace(/"/g, "")
      filename = path.join path.dirname(asset.from), filename
      str = str.replace "@@import=#{i}", "@import \"#{filename}\""

   return str

mod.runCommands = (commands, silent, done) ->
   unless commands and commands?.length > 0 then return
   startTime = new Date() / 1 unless silent

   run = (entry, next) ->

      unless silent then console.log "\t#{white}#{entry.command}#{reset}"
      exec entry.command, (err, stdout, stderr) ->
         
         unless silent
            color = if err then red else green
            result = (stderr or stdout or "(no output)\n").replace(/\n/g, "\n\t\t")
            output = "\n\t\t#{color}#{result}#{reset}"
            console.log output
            
         if err 
            if entry.on_error == "continue"
               console.log "#{color}\n(continuing after error)#{reset}" unless silent
            else
               console.log "#{color}\n(stopping after error)#{reset}" unless silent
               return next err

         next()

   async.forEachSeries commands, run, (err) ->
      if err and not silent
         ms = (new Date() / 1) - startTime
         console.log "#{white}Finished #{green}(#{ms} ms)#{reset}" 

   
