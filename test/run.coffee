require "mocha"
path = require "path"
fs = require "fs-extra"
should = require "should"
build_action = require "../actions/build"
exec = require('child_process').exec

currentDir = process.cwd()

describe "gapify", () ->

   describe "build action", () ->
     
      describe "changeWorkingDirectory", () ->
         afterEach () ->
            process.chdir currentDir   

         it "should change working directory", () ->
            current = process.cwd()
            build_action.changeWorkingDirectory("test")
            process.cwd().should.equal(path.join current, "test")

         it "should not change working directory if no parameters", () ->
            current = process.cwd()
            build_action.changeWorkingDirectory()
            process.cwd().should.equal current

         it "should throw exception on nonexistant directory", () ->
            ( () ->
              build_action.changeWorkingDirectory("blah-blah")
            ).should.throw()

      describe "createOutputDirectory", () ->
         before () ->
            build_action.changeWorkingDirectory "test"
         after () ->
            process.chdir currentDir   

         it "should create directory", () ->
            build_action.createOutputDirectory "bin"
            fs.existsSync(path.join process.cwd(), "bin").should.be.true

         it "should empty directory if options is set", () ->
            filepath = path.join(process.cwd(), "bin/test.txt")
            fs.writeFileSync filepath, "test"
            build_action.createOutputDirectory "bin", true
            fs.existsSync(filepath).should.be.false
            
      describe "compileViews", () ->
         output = null
         before () ->
            build_action.changeWorkingDirectory "test"
            build_action.createOutputDirectory "bin"
            output = path.join(process.cwd(), "bin")
            config = { directory: "assets/views", ignore: ["layout.jade"] } 
            build_action.compileViews config, output
         after () ->
            fs.removeSync output
            process.chdir currentDir 

         it "should compile jade templates and rename with path", () ->
            fs.existsSync(path.join(output, "test.html")).should.be.true
            fs.existsSync(path.join(output, "sub-deep.html")).should.be.true

         it "should ignore layouts", () ->
            fs.existsSync(path.join(output, "layout.html")).should.be.false

         it "should correctly compile to html", () ->
            checkAgainstFile path.join(output, "test.html"), path.join(process.cwd(), "assets/test.html")

      describe "compileAsset", () ->
         output = null
         before () ->
            build_action.changeWorkingDirectory "test"
            build_action.createOutputDirectory "bin"
            output = path.join(process.cwd(), "bin")
         after () ->
            fs.removeSync output
            process.chdir currentDir 

         describe "with compile 'none'", () ->
            afterEach () ->
               fs.removeSync output

            it "should copy file", (done) ->
               asset = 
                  from: "assets/test.html"
                  to: "{out}/text.html"
               build_action.copyAssets [asset], false, output, () ->
                  fs.existsSync(path.join(output, "text.html")).should.be.true
                  done()

            it "should copy folder", (done) ->
               asset = 
                  from: "assets/views/sub"
                  to: "{out}/sub"
               build_action.copyAssets [asset], false, output, () ->
                  fs.existsSync(path.join(output, "sub/deep.jade")).should.be.true
                  done()

         describe "with compile 'coffee'", () ->
            before (done) ->
               asset =
                  from: "assets/test.coffee"
                  to: "{out}/test.js"
               build_action.copyAssets [asset], false, output, done

            it "should copy file to correct directory", () ->
               checkExistance path.join(output, "test.js")

            it "should compile files and minify", () ->
               checkAgainstFile path.join(output, "test.js"), path.join(process.cwd(), "assets/test.js")

            it "should compile and not minify if set to debugging", (done) ->
               asset = 
                  from: "assets/test.coffee"
                  to: "{out}/test.js"
               build_action.copyAssets [asset], true, output, () ->
                  checkAgainstFile path.join(output, "test.js"), path.join(process.cwd(), "assets/test-debug.js")
                  done()

         describe "with compile 'stylus'", () ->
            before (done) ->
               asset = 
                  from: "assets/test.styl"
                  to: "{out}/test.css"
               build_action.copyAssets [asset], false, output, done

            it "should copy file to correct directory", () ->
               checkExistance path.join(output, "test.css")

            it "should compile imported stylus files", () ->
               checkAgainstFile path.join(output, "test.css"), path.join(process.cwd(), "assets/test.css")

      describe "command-line", () ->

         it "should complete without errors", (done) ->
            exec "./gapify build -s -c ./test/assets", (err) ->
               return done err if err
               checkAgainstFile "./test/bin/test.html", "./test/assets/test.html"
               checkAgainstFile "./test/bin/js/test.js", "./test/assets/test.js"
               checkAgainstFile "./test/bin/css/test.css", "./test/assets/test.css"
               checkExistance "./test/bin/sub"
               fs.removeSync "./test/bin"
               done()

         it "should complete with --debug option", (done) ->
            exec "./gapify build -sd -c ./test/assets", (err) ->
               return done err if err
               checkAgainstFile "./test/bin/test.html", "./test/assets/test.html"
               checkAgainstFile "./test/bin/js/test.js", "./test/assets/test-debug.js"
               checkAgainstFile "./test/bin/css/test.css", "./test/assets/test.css"
               checkExistance "./test/bin/sub"
               fs.removeSync "./test/bin"
               done()

         it "should complete with --output option", (done) ->
            exec "./gapify build -s -c ./test/assets -o ../otherbin", (err) ->
               return done err if err
               checkAgainstFile "./test/otherbin/test.html", "./test/assets/test.html"
               checkAgainstFile "./test/otherbin/js/test.js", "./test/assets/test.js"
               checkAgainstFile "./test/otherbin/css/test.css", "./test/assets/test.css"
               checkExistance "./test/otherbin/sub"
               fs.removeSync "./test/otherbin"
               done()

checkExistance = (entity) ->
   fs.existsSync(entity).should.be.true

checkAgainstFile = (compiled, correct) ->
   compiled = fs.readFileSync(compiled).toString()
   correct = fs.readFileSync(correct).toString()
   compiled.should.equal(correct)