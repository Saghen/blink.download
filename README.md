# Blink Download (blink.download)

Neovim libary for downloading pre-built binaries for rust based Neovim plugins.

## Usage

Add the following at the top level of your plugin:

```lua
local download = require('blink.download')

local my_plugin = {}

function my_plugin.setup()
  download.ensure_downloaded({
    -- omit this property to disable downloading
    download_url = function(version, system_triple, extension)
      return 'https://github.com/saghen/blink.delimiters/releases/download/' .. version .. '/' .. system_triple .. extension
    end,

    module_name = 'blink.delimiters',
    -- optional, defualts to module_name with `.` replaced with `_`
    -- binary_name = 'blink_delimiters',
  }, function(err, module)
    if err then error(err) end

    -- rest of your setup

    -- optionally, load the module directly elsewhere in your plugin
    local module = require('blink_delimiters')
  end)
end
```



