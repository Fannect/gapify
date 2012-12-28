fs = require "fs-extra"
path = require "path"
_ = require "underscore"
snockets = new (require "snockets")()
stylus = require "stylus"
jade = require "jade"

config = null
outDir = null
originalDir = null

module.exports = (program) ->
   originalDir = process.cwd()

   if not changeDirectory(program) then return
   if not loadConfig() then return
   
   createOutFolder(program)
   compileViews()
   copyAssets () ->
      process.chdir originalDir
      console.log "Complete."

changeDirectory = (program) ->
   if program.chdir
      try  
         process.chdir program.chdir
      catch e
         console.log "chdir: invalid directory"
         return false
   return true

loadConfig = () ->
   try
      defaultOptions = require "./default.json"
      userOptions = require path.join process.cwd(), "gapify.json"
      config = _.extend defaultOptions, userOptions
   catch e
      console.log "error with 'gapify.json':", e
      return false
   return true

createOutFolder = (program) ->
   outDir = path.join process.cwd(), config.output   
   unless fs.existsSync outDir then fs.mkdirsSync outDir

compileViews = () ->
   viewDir = path.join process.cwd(), config.views.directory

   compileViewDirectory = (dir) ->
      list = fs.readdirSync dir

      for file in list
         filePath = path.resolve dir, file
         stat = fs.statSync filePath

         if stat and stat.isDirectory()
            compileViewDirectory filePath
         else
            oldFilename = filePath.replace(viewDir, "").replace(/^[\\\/]/g, "")
            unless oldFilename in config.views.ignore
               filename = oldFilename.replace("jade", "html").replace(/[\\\/]/g, "-")
               contents = fs.readFileSync filePath
               html = jade.compile(contents,
                  debug: false
                  filename: filePath
               )({settings: {views:viewDir}, filename: filePath})
               fs.writeFileSync path.join(outDir, filename), html

   compileViewDirectory viewDir

copyAssets = (done) ->
   counter = config.assets.length
   if counter == 0 then done() if done
   for asset in config.assets
      asset.from = path.join process.cwd(), asset.from
      asset.to = asset.to.replace("{out}", outDir)
      
      # Ensure directory exists
      folder = if asset.is_directory then asset.to else path.dirname asset.to
      unless fs.existsSync folder then fs.mkdirsSync folder

      # Compile assets
      compileAsset[asset.compile] asset, (err) ->
         throw err if err
         if --counter == 0 then done() if done

compileAsset = 
   none: (asset, done) -> fs.copy asset.from, asset.to, done
   coffee: (asset, done) ->
      snockets.getConcatenation asset.from, minify: true, (err, js) ->
         throw err if err
         fs.writeFile asset.to, js, done 
   stylus: (asset, done) ->
      fs.readFile asset.from, (err, data) ->
         throw err if err
         # Fix paths to imports
         str = fixImportPaths(asset, data.toString())

         stylus.render str, {filename: asset.from}, (err, css) ->
            throw err if err
            fs.writeFile asset.to, css, done

fixImportPaths = (asset, str) ->
   imports = str.match /^@import[/w]*.+$/gm

   for im, i in imports
      str = str.replace /^@import[/w]*.+$/m, "@@import=#{i}"

   for im, i in imports
      filename = im.match(/"(?:[^\\"]+|\\.)*"/)[0].toString().replace(/"/g, "")
      filename = path.join path.dirname(asset.from), filename
      str = str.replace "@@import=#{i}", "@import \"#{filename}\""

   return str

   
