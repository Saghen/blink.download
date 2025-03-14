local async = require('blink.download.lib.async')
local git = require('blink.download.git')

--- @class blink.download.Options
--- @field download_url (fun(version: string): string) | nil
--- @field root_dir string
--- @field output_dir string
--- @field binary_name string
--- @field force_version string | nil

--- @class blink.download.API
local download = {}

--- @param options blink.download.Options
--- @param callback fun(err: string | nil)
--- @param on_download fun()
function download.ensure_downloaded(options, callback, on_download)
  callback = vim.schedule_wrap(callback)

  local files = require('blink.download.files').new(options.root_dir, options.output_dir)
  require('blink.download.cpath')(files.lib_dir)

  async.task
    .await_all({ git.get_version(files.root_dir), files:get_version() })
    :map(function(results) return { git = results[1], current = results[2] } end)
    :map(function(version)
      -- no version file found, user manually placed the .so file or build the plugin manually
      if version.current.missing then
        local shared_library_found, _ = pcall(require, options.binary_name)
        if shared_library_found then return end
      end

      -- downloading disabled, not built locally
      if not options.download_url then error('No rust library found, but downloading is disabled.') end

      -- downloading enabled, not on a git tag
      local target_git_tag = options.force_version or version.git.tag
      if target_git_tag == nil then
        error("No rust library found, but can't download due to not being on a git tag.")
      end

      -- already downloaded and the correct version
      if version.current.tag == target_git_tag then return end

      -- download
      vim.schedule(function() on_download() end)
      local downloader = require('blink.download.downloader')
      return downloader.download(files, options.download_url, target_git_tag)
    end)
    :map(function() callback() end)
    :catch(function(err) callback(err) end)
end

return download
