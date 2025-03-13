local async = require('blink.download.lib.async')
local git = require('blink.download.git')

--- @class blink.download.Options
--- @field download_url (fun(version: string): string) | nil
--- @field module_name string | nil
--- @field binary_name string | nil
--- @field force_version string | nil

--- @class blink.download.API
local download = {}

--- @param options blink.download.Options
--- @param callback fun(err: string | nil, module: any | nil)
function download.ensure_downloaded(options, callback)
  callback = vim.schedule_wrap(callback)
  if not options.binary_name then options.binary_name = options.module_name:gsub('%.', '_') end

  local notify = function(msg, level)
    vim.schedule(
      function()
        vim.notify(
          '[' .. options.module_name .. ']: ' .. msg,
          level or vim.log.levels.WARN,
          { title = options.module_name }
        )
      end
    )
  end

  local files = require('blink.download.files').new(options.module_name, options.binary_name)

  async.task
    .await_all({ git.get_version(), files.get_version() })
    :map(function(results)
      return {
        git = results[1],
        current = results[2],
      }
    end)
    :map(function(version)
      -- no version file found, user manually placed the .so file or build the plugin manually
      if version.current.missing then
        local shared_library_found, _ = pcall(require('blink.download.load'), options.module_name)
        if shared_library_found then return end
      end

      -- downloading disabled but not built locally
      if not options.download_url then error('No rust library found, but downloading is disabled.') end

      local target_git_tag = options.force_version or version.git.tag

      -- downloading enabled but not on a git tag
      if target_git_tag == nil then
        error("No rust library found, but can't download due to not being on a git tag.")
      end

      -- already downloaded and the correct version
      if version.current.tag == target_git_tag then return end

      -- download as per usual
      notify('Downloading pre-built binary...')
      local downloader = require('blink.download.downloader')
      return downloader.download(files, options.download_url, target_git_tag)
    end)
    :map(function() callback(nil, require('blink.download.load')(options.binary_name)) end)
    :catch(function(err) callback(err) end)
end
