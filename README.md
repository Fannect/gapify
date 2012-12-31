# Gapify
### Command-line tool to compile Express apps into PhoneGap apps

It turned out to be a fairly flexible tool that can be used by anyone who wants to move files around and compile CoffeeScript, Jade, or Stylus files. More files types should be supported soon.

## Configuration

Gapify relies on a configuration file, `gapify.json`, in the root directory. Here is a sample configuration.

```javascript
{
   "output": "../fannect-phonegap",
   "assets": [
      {
         "from":"assets/js/tree.coffee",
         "to":"{out}/js/tree.js"
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
         "from":"public/images",
         "to":"{out}/images"
      }
   ],
   "views": {
      "directory":"views",
      "ignore":["layout.jade"]
   },
   "on_success": [
      {
         "command": "git add . -A",
         "on_error": "stop"
      },
      {
         "command": "git commit -m \"Auto update by Gapify.\"",
         "on_error": "continue"
      },
      {
         "command": "git push origin master",
         "on_error": "stop"
      }
   ]
}
```

### Sections