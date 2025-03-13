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
    -- i.e. https://github.com/Saghen/blink.delimiters/releases/download/v0.1.0/x86_64-unknown-linux-gnu.so
    download_url = function(version, system_triple, extension)
      return 'https://github.com/saghen/blink.delimiters/releases/download/' .. version .. '/' .. system_triple .. extension
    end,

    module_name = 'blink.delimiters',
    -- optional, defaults to module_name with `.` replaced with `_`
    -- binary_name = 'blink_delimiters',
  }, function(err, module)
    if err then error(err) end

    -- rest of your setup

    -- optionally, load the module directly elsewhere in your plugin
    local module = require('blink_delimiters')
  end)
end
```


Add the following to your `build.rs` to ensure. This deletes the `version` file created by the downloader, such that the downloader will accept the binary as-is.

```rust
fn main() {
    // delete existing version file created by downloader
    let _ = std::fs::remove_file("target/release/version");
}
```
