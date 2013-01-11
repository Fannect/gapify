exec = require('child_process').exec
async = require "async"

# Colors for console.log
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

class CommandRunner

   constructor: () ->
      @child_processes = []

   run: (commands, silent, done) ->
      @killCommands()

      that = @
      unless commands and commands?.length > 0 then return
      startTime = new Date() / 1 unless silent

      runCommand = (entry, next) ->
         console.log "\t#{white}#{entry.command}#{reset}\n" unless silent 
         
         child = exec entry.command, (err, stdout, stderr) ->
            that.child_processes.splice index, 1
            unless silent
               color = if err then red else green
               if not stderr and not stdout
                  console.log "\t\t#{color}(no output)#{reset}\n"
               else 
                  console.log "\n"
               
            if err 
               if entry.on_error == "continue"
                  console.log "#{color}\t\t(continuing after error)#{reset}\n" unless silent
               else
                  console.log "#{color}\t\t(stopping after error)#{reset}\n" unless silent
                  return next err
            next()

         index = that.child_processes.length
         that.child_processes.push child

         unless silent
            child.stdout.on "data", (data) ->
               console.log ("\t\t#{green}#{data}#{reset}").replace(/\n/g, "")
            child.stderr.on "data", (data) ->
               console.log ("\t\t#{red}#{data}#{reset}").replace(/\n/g, "")

      async.forEachSeries commands, runCommand, (err) ->
         unless silent
            ms = (new Date() / 1) - startTime
            console.log "#{white}Finished #{green}(#{ms} ms)#{reset}" 
         done() if done

   killCommands: () ->
      for child in @child_processes
         child.kill()
      @child_processes.length = 0

module.exports = CommandRunner


