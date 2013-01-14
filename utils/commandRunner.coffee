exec = require('child_process').exec
async = require "async"

# Colors for console.log
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

class CommandRunner

   constructor: () ->
      @running_command = null
      @callbacks = []

      process.on "exit", () =>
         @killRunningCommand()

   run: (commands, silent, done) ->
      @killRunningCommand()
      @callbacks.push done

      unless commands and commands?.length > 0 then return
      startTime = new Date() / 1 unless silent
      cwd = process.cwd()

      runCommand = (entry, next) =>
         process.chdir cwd
         
         console.log "\t#{white}#{entry.command}#{reset}\n" unless silent 
         @running_command = exec entry.command, (err, stdout, stderr) =>

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

         unless silent
            @running_command.stdout.on "data", (data) ->
               console.log ("\t\t#{green}#{data}#{reset}").replace(/\n/g, "")
            @running_command.stderr.on "data", (data) ->
               console.log ("\t\t#{red}#{data}#{reset}").replace(/\n/g, "")

      async.forEachSeries commands, runCommand, (err) =>
         unless silent
            ms = (new Date() / 1) - startTime
            console.log "#{white}Finished #{green}(#{ms} ms)#{reset}" 
         
         @.callComplete()

   onComplete: (done) ->
      @callbacks.push done
      return @

   callComplete: () ->
      if done then done() for done in @callbacks
      @callbacks.length = 0

   killRunningCommand: () ->
      if @running_command
         @running_command.kill("SIGINT")
         console.log "Is kill:", @running_command.killed
         running_command = null

module.exports = CommandRunner


