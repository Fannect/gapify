# Gapify
### Command-line tool to compile Express apps into PhoneGap apps
[![Build Status](https://secure.travis-ci.org/Fannect/gapify.png?branch=master)](https://travis-ci.org/Fannect/gapify)

It turned out to be a fairly flexible tool that can be used by anyone who wants to move files around and compile CoffeeScript, Jade, or Stylus files. More files types should be supported soon.

## Configuration

Gapify relies on a configuration file, `gapify.json`, in the root directory. Here is a sample configuration.

```javascript
{
   "output": "./bin", // specifies the output directory
   "assets": [
      {
         "from":"assets/js/tree.coffee", // file type is inferred from extension
         "to":"{out}/js/tree.js" // `{out}` is replaced by output directory
      },
      {
         "from":"assets/css/skin.styl",
         "to":"{out}/css/skin.css"
      },
      {
         "from":"assets/css/lib/fannect.css",
         "to":"{out}/css/lib/fannect.css"
      },
      {
         "from":"public/images", // directories can be copied (included subdirectories)
         "to":"{out}/images"
      }
   ],
   "views": {
      "directory":"views", // directory of all the Jade templates
      "ignore":["layout.jade"] // files that are layouts and should be ignored
   },
   "on_success": [ // this section allows for terminal commands to be executed on success compilation
      {
         "command": "git add . -A", // commands are executed with output directory as the working directory
         "on_error": "stop" // does NOT execute following commands on an error
      },
      {
         "command": "git commit -m \"Auto update by Gapify.\"",
         "on_error": "continue" // DOES execute following commands on an error
      },
      {
         "command": "git push origin master",
         "on_error": "stop"
      }
   ]
}
```
When using PhoneGap, file paths using the root (such as `/blah`) are not resolved correctly. To compensate, the folder structure of the views is flattened and all files in the view directory are renamed according to their previous folder structure.

Example: `sub/example.jade` -> `sub-example.html`

## Install
```
npm install -g gapify
```

## Command-line Options
```
   Usage: gapify [options] [command]
   
   Commands:
   
      build                   compile to PhoneGap compliant app
      
   Options:
   
      -h, --help              output usage information
      -o, --output <path>     change the output directory, overrides config file
      -c, --chdir <path>      change the working directory
      -e, --empty             empties output directory before compilation (excluding .gt and .gitignore)
      -d, --debug             does not minify JS and CSS
      -s, --silent            suppresses console output
      
```

## Running the Tests
```
npm test
```
