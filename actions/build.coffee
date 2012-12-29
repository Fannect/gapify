fs = require "fs-extra"
path = require "path"
_ = require "underscore"
snockets = new (require "snockets")()
stylus = require "stylus"
jade = require "jade"

mod = module.exports = (program, done) ->
   originalDir = process.cwd()

   mod.changeWorkingDirectory(program.chdir)
   config = mod.loadConfig()
   outDir = path.join process.cwd(), program.output or config.output 
   
   mod.createOutputDirectory(outDir, program.empty or false)
   mod.compileViews config.views, outDir
   mod.copyAssets config.assets, outDir, () ->
      process.chdir originalDir
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

mod.copyAssets = (assets, outDir, done) ->
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
      compileFn asset, (err) ->
         throw err if err
         if --counter <= 0 then done() if done

mod.compileAsset = 
   none: (asset, done) -> fs.copy asset.from, asset.to, done
   coffee: (asset, done) ->
      snockets.getConcatenation asset.from, minify: true, (err, js) ->
         throw err if err
         fs.writeFile asset.to, js, done 
   styl: (asset, done) ->
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

   
