# Blink Download (blink.download)

Neovim libary for downloading pre-built binaries for Rust based plugins. For a quick start, see the [neovim-lua-rust-template](https://github.com/Saghen/neovim-lua-rust-template).

## Usage

Add the following at the top level of your plugin:

```lua
local my_plugin = {}

function my_plugin.setup()
  -- get the root directory of the plugin, by getting the relative path to this file
  -- for example, if this file is in `/lua/my_plugin.lua`, use `../../`
  local root_dir = vim.fn.resolve(debug.getinfo(1).source:match('@?(.*/)') .. '../../')

  require('blink.download').ensure_downloaded({
    -- omit this property to disable downloading
    -- i.e. https://github.com/Saghen/blink.delimiters/releases/download/v0.1.0/x86_64-unknown-linux-gnu.so
    download_url = function(version, system_triple, extension)
      return 'https://github.com/saghen/blink.delimiters/releases/download/' .. version .. '/' .. system_triple .. extension
    end,

    root_dir,
    output_dir = '/target/release',
    binary_name = 'blink_delimiters' -- excluding `lib` prefix
  }, function(err)
    if err then error(err) end

    local rust_module = require('blink_delimiters')
  end)
end
```


Add the following to your `build.rs`. This deletes the `version` file created by the downloader, such that the downloader will accept the binary as-is.

```rust
fn main() {
    // delete existing version file created by downloader
    let _ = std::fs::remove_file("target/release/version");
}
```
