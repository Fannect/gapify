#!/usr/bin/env node

require("coffee-script");
var program = require("commander");

var build_action = require("./actions/build");

program
   .version("0.0.1")
   .option("-o, --output <path>", "change the output directory, defaults to '/bin'")
   .option("-c --chdir <path>", "change the working directory")
   .option("-e --empty", "empties output directory (excluding .git and .gitignore)");

program
   .command("build")
   .description("compile to PhoneGap compliant app")
   .action(function (cmd) {
      build_action(program);
   });

program.parse(process.argv);