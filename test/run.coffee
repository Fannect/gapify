require "mocha"
path = require "path"
fs = require "fs-extra"
should = require "should"
build_action = require "../actions/build"

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
            compiled = fs.readFileSync(path.join(output, "test.html")).toString()
            correct = fs.readFileSync(path.join(process.cwd(), "/assets/test.html")).toString()
            compiled.should.equal(correct)

      describe "compileAsset", () ->
         output = null
         before () ->
            build_action.changeWorkingDirectory "test"
            build_action.createOutputDirectory "bin"
            output = path.join(process.cwd(), "bin")
         afterEach () ->
            fs.removeSync output
         after () ->
            process.chdir currentDir 

         describe "with compile 'none'", () ->

            it "should copy file", (done) ->
               asset = 
                  from: path.join(process.cwd(), "assets/test.html")
                  to: path.join output, "text.html"
                  compile: "none",
                  is_directory: false
               build_action.compileAsset["none"] asset, () ->
                  fs.existsSync(asset.to).should.be.true
                  done()

            it "should copy folder", (done) ->
               asset = 
                  from: path.join(process.cwd(), "assets/test.html")
                  to: path.join output, "text.html"
                  compile: "none",
                  is_directory: false
               build_action.compileAsset["none"] asset, () ->
                  fs.existsSync(asset.to).should.be.true
                  done()


