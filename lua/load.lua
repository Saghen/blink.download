local cpath_set = false
local function init_cpath()
  if cpath_set then return end

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
    .. debug.getinfo(1).source:match('@?(.*/)')
    .. '../../../../../target/release/lib?'
    .. get_lib_extension()
    .. ';'
    .. debug.getinfo(1).source:match('@?(.*/)')
    .. '../../../../../target/release/?'
    .. get_lib_extension()

  cpath_set = true
end

--- @param module string
local function load(module)
  init_cpath()
  return require(module)
end

return load
