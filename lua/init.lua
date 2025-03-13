local async = require('blink.download.lib.async')
local git = require('blink.download.git')
local files = require('blink.download.files')
local system = require('blink.download.system')
local config = require('blink.download.config')

--- @class blink.download.Options
--- @field module string
--- @field download boolean
--- @field verify_checksum boolean
--- @field verify_sha boolean
--- @field force_version string | nil

--- @class blink.download.API
local download = {}

--- @param options blink.download.Options
--- @param callback fun(err: string | nil, module: any | nil)
function download.ensure_downloaded(options, callback)
  callback = vim.schedule_wrap(callback)

  local load = require('blink.download.load')

  local notify = function(msg, level)
    vim.schedule(
      function()
        vim.notify('[' .. options.module .. ']: ' .. msg, level or vim.log.levels.WARN, { title = options.module })
      end
    )
  end

  async.task
    .await_all({ git.get_version(), files.get_version() })
    :map(function(results)
      return {
        git = results[1],
        current = results[2],
      }
    end)
    :map(function(version)
      -- no version file found, user manually placed the .so file, or the plugin doesn't output a sha after building
      if version.current.missing then
        local shared_library_found, _ = pcall(load, options.module)
        if shared_library_found then return end
      end

      local target_git_tag = options.force_version or version.git.tag

      -- built locally
      if version.current.sha ~= nil then
        -- up to date or ignoring version mismatch, ignore
        if version.current.sha == version.git.sha or not options.verify_sha then return end

        notify('Found an outdated version of the locally built fuzzy matching library')

        -- downloading enabled but not on a git tag, error
        if options.download then
          if target_git_tag == nil then
            error(
              "Found an outdated version of the fuzzy matching library, but can't download from github due to not being on a git tag."
            )
          end

        -- downloading is disabled, error
        else
          error('Found an outdated version of the fuzzy matching library, but downloading from github is disabled.')
        end
      end

      -- downloading disabled but not built locally
      if not options.download then
        error('No fuzzy matching library found, but downloading from github is disabled.')
      end

      -- downloading enabled but not on a git tag
      if target_git_tag == nil then
        notify('No fuzzy matching library found')

        error(
          "No fuzzy matching library found, but can't download from github due to not being on a git tag and no `fuzzy.prebuilt_binaries.force_version` is set."
            .. '\nEither run `cargo build --release` via your package manager, switch to a git tag, or set `fuzzy.prebuilt_binaries.force_version` in config.'
            .. '\nSee the docs for more info.'
        )
      end

      -- already downloaded and the correct version, just verify the checksum, and re-download if checksum fails
      if version.current.tag == target_git_tag then
        if not options.verify_checksum then return end

        return files.verify_checksum():catch(function(err)
          notify(err)
          if not options.download then
            error('Pre-built binary failed checksum verification, but downloading is disabled')
          end

          notify('Pre-built binary failed checksum verification, re-downloading')
          return download.download(target_git_tag)
        end)
      end

      -- download as per usual
      notify('Downloading pre-built binary')
      return download.download(target_git_tag)
    end)
    :map(function() callback(nil, 'rust') end)
    :catch(function(err) callback(err) end)
end

function download.download(base_url, version)
  -- NOTE: we set the version to 'v0.0.0' to avoid a failure causing the pre-built binary being marked as locally built
  return files
    .set_version('v0.0.0')
    :map(function() return download.from_github(base_url, version) end)
    :map(function() return files.verify_checksum() end)
    :map(function() return files.set_version(version) end)
end

--- @param base_url string
--- @param version string
--- @return blink.cmp.Task
function download.from_github(base_url, version)
  return system.get_triple():map(function(system_triple)
    if not system_triple then
      return error(
        'Your system is not supported by pre-built binaries. You must run cargo build --release via your package manager with rust nightly. See the README for more info.'
      )
    end

    local version_url = base_url .. version .. '/'
    local library_url = version_url .. system_triple .. files.get_lib_extension()
    local checksum_url = version_url .. system_triple .. files.get_lib_extension() .. '.sha256'

    return async
      .task
      .await_all({
        download.download_file(library_url, files.lib_filename .. '.tmp'),
        download.download_file(checksum_url, files.checksum_filename),
      })
      -- Mac caches the library in the kernel, so updating in place causes a crash
      -- We instead write to a temporary file and rename it, as mentioned in:
      -- https://developer.apple.com/documentation/security/updating-mac-software
      :map(
        function()
          return files.rename(
            files.lib_folder .. '/' .. files.lib_filename .. '.tmp',
            files.lib_folder .. '/' .. files.lib_filename
          )
        end
      )
  end)
end

--- @param url string
--- @param filename string
--- @return blink.cmp.Task
function download.download_file(url, filename)
  return async.task.new(function(resolve, reject)
    local args = { 'curl' }

    -- Use https proxy if available
    if config.proxy.url ~= nil then
      vim.list_extend(args, { '--proxy', config.proxy.url })
    elseif config.proxy.from_env then
      local proxy_url = os.getenv('HTTPS_PROXY')
      if proxy_url ~= nil then vim.list_extend(args, { '--proxy', proxy_url }) end
    end

    vim.list_extend(args, config.extra_curl_args)
    vim.list_extend(args, {
      '--fail', -- Fail on 4xx/5xx
      '--location', -- Follow redirects
      '--silent', -- Don't show progress
      '--show-error', -- Show errors, even though we're using --silent
      '--create-dirs',
      '--output',
      files.lib_folder .. '/' .. filename,
      url,
    })

    vim.system(args, {}, function(out)
      if out.code ~= 0 then
        reject('Failed to download ' .. filename .. 'for pre-built binaries: ' .. out.stderr)
      else
        resolve()
      end
    end)
  end)
end
