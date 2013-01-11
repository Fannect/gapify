exec = require('child_process').exec
async = require "async"

# Colors for console.log
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

module.exports = (commands, silent, done) ->

   unless commands and commands?.length > 0 then return
   startTime = new Date() / 1 unless silent

   run = (entry, next) ->
      console.log "\t#{white}#{entry.command}#{reset}\n" unless silent 
      child = exec entry.command, (err, stdout, stderr) ->
         
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
         child.stdout.on "data", (data) ->
            console.log ("\t\t#{green}#{data}#{reset}").replace(/\n/g, "")
         child.stderr.on "data", (data) ->
            console.log ("\t\t#{red}#{data}#{reset}").replace(/\n/g, "")

   async.forEachSeries commands, run, (err) ->
      unless silent
         ms = (new Date() / 1) - startTime
         console.log "#{white}Finished #{green}(#{ms} ms)#{reset}" 
      done() if done