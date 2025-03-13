local async = require('blink.download.lib.async')
local utils = require('blink.download.lib.utils')
local system = require('blink.download.system')

local files = {}

--- @param module_name string
--- @param binary_name string
function files.new(module_name, binary_name)
  local root_dir = package.searchpath(module_name, package.path)

  local lib_folder = root_dir .. '/target/release'
  local lib_filename = 'lib' .. binary_name .. utils.get_lib_extension()
  local lib_path = lib_folder .. '/' .. lib_filename

  local self = setmetatable({}, { __index = files })

  self.root_dir = root_dir
  self.lib_folder = lib_folder
  self.lib_filename = lib_filename
  self.lib_path = lib_path
  self.checksum_path = lib_path .. '.sha256'
  self.checksum_filename = lib_filename .. '.sha256'
  self.version_path = lib_folder .. '/version'

  return self
end

--- Checksums ---

function files:get_checksum()
  return files.read_file(self.checksum_path):map(function(checksum) return vim.split(checksum, ' ')[1] end)
end

function files.get_checksum_for_file(path)
  return async.task.new(function(resolve, reject)
    local os = system.get_info()
    local args
    if os == 'linux' then
      args = { 'sha256sum', path }
    elseif os == 'mac' or os == 'osx' then
      args = { 'shasum', '-a', '256', path }
    elseif os == 'windows' then
      args = { 'certutil', '-hashfile', path, 'SHA256' }
    end

    vim.system(args, {}, function(out)
      if out.code ~= 0 then return reject('Failed to calculate checksum of pre-built binary: ' .. out.stderr) end

      local stdout = out.stdout or ''
      if os == 'windows' then stdout = vim.split(stdout, '\r\n')[2] end
      -- We get an output like 'sha256sum filename' on most systems, so we grab just the checksum
      return resolve(vim.split(stdout, ' ')[1])
    end)
  end)
end

function files:verify_checksum()
  return async.task
    .await_all({ files:get_checksum(), files.get_checksum_for_file(self.lib_path) })
    :map(function(checksums)
      assert(#checksums == 2, 'Expected 2 checksums, got ' .. #checksums)
      assert(checksums[1] and checksums[2], 'Expected checksums to be non-nil')
      assert(
        checksums[1] == checksums[2],
        'Checksum of pre-built binary does not match. Expected "' .. checksums[1] .. '", got "' .. checksums[2] .. '"'
      )
    end)
end

--- Prebuilt binary ---

function files:get_version()
  return files
    .read_file(self.version_path)
    :map(function(version)
      if #version == 40 then
        return { sha = version }
      else
        return { tag = version }
      end
    end)
    :catch(function() return { missing = true } end)
end

--- @param version string
--- @return blink.cmp.Task
function files:set_version(version)
  return files
    .create_dir(self.root_dir .. '/target')
    :map(function() return files.create_dir(self.lib_folder) end)
    :map(function() return files.write_file(self.version_path, version) end)
end

--- Filesystem helpers ---

--- @param path string
--- @return blink.cmp.Task
function files.read_file(path)
  return async.task.new(function(resolve, reject)
    vim.uv.fs_open(path, 'r', 438, function(open_err, fd)
      if open_err or fd == nil then return reject(open_err or 'Unknown error') end
      vim.uv.fs_read(fd, 1024, 0, function(read_err, data)
        vim.uv.fs_close(fd, function() end)
        if read_err or data == nil then return reject(read_err or 'Unknown error') end
        return resolve(data)
      end)
    end)
  end)
end

--- @param path string
--- @param data string
--- @return blink.cmp.Task
function files.write_file(path, data)
  return async.task.new(function(resolve, reject)
    vim.uv.fs_open(path, 'w', 438, function(open_err, fd)
      if open_err or fd == nil then return reject(open_err or 'Unknown error') end
      vim.uv.fs_write(fd, data, 0, function(write_err)
        vim.uv.fs_close(fd, function() end)
        if write_err then return reject(write_err) end
        return resolve()
      end)
    end)
  end)
end

--- @param path string
--- @return blink.cmp.Task
function files.exists(path)
  return async.task.new(function(resolve)
    vim.uv.fs_stat(path, function(err) resolve(not err) end)
  end)
end

--- @param path string
--- @return blink.cmp.Task
function files.stat(path)
  return async.task.new(function(resolve, reject)
    vim.uv.fs_stat(path, function(err, stat)
      if err then return reject(err) end
      resolve(stat)
    end)
  end)
end

--- @param path string
--- @return blink.cmp.Task
function files.create_dir(path)
  return files
    .stat(path)
    :map(function(stat) return stat.type == 'directory' end)
    :catch(function() return false end)
    :map(function(exists)
      if exists then return end

      return async.task.new(function(resolve, reject)
        vim.uv.fs_mkdir(path, 511, function(err)
          if err then return reject(err) end
          resolve()
        end)
      end)
    end)
end

--- Renames a file
--- @param old_path string
--- @param new_path string
function files.rename(old_path, new_path)
  return async.task.new(function(resolve, reject)
    vim.uv.fs_rename(old_path, new_path, function(err)
      if err then return reject(err) end
      resolve()
    end)
  end)
end

return files
