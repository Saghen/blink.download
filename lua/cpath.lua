local utils = require('blink.download.utils')

--- @type table<string, boolean>
local cpath_set_by_module = {}

--- @param module_name string
local function init_cpath(module_name)
  if cpath_set_by_module[module_name] then return end

  local path = utils.get_module_path(module_name)

  --- @return string
  local function get_lib_extension()
    if jit.os:lower() == 'mac' or jit.os:lower() == 'osx' then return '.dylib' end
    if jit.os:lower() == 'windows' then return '.dll' end
    return '.so'
  end

  -- search for the lib in the /target/release directory with and without the lib prefix
  -- since MSVC doesn't include the prefix
  package.cpath = package.cpath
    .. ';'
    .. path
    .. '/target/release/lib?'
    .. get_lib_extension()
    .. ';'
    .. path
    .. '/target/release/?'
    .. get_lib_extension()

  cpath_set_by_module[module_name] = true
end

return init_cpath
