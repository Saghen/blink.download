local async = require('blink.download.async')

--- @class blink.download.Git
local git = {}

--- @param module_name string
--- @return blink.cmp.Task
function git.get_tag(module_name)
  local path = package.searchpath(module_name, package.path)
  if not path then
    return async.task.new(function() error('Module not found: ' .. module_name) end)
  end

  return async.task.new(function(resolve, reject)
    vim.system({ 'git', 'describe', '--tags', '--exact-match' }, { cwd = path }, function(out)
      if out.code == 128 then return resolve() end
      if out.code ~= 0 then
        return reject('While getting git tag, git exited with code ' .. out.code .. ': ' .. out.stderr)
      end

      local lines = vim.split(out.stdout, '\n')
      if not lines[1] then return reject('Expected atleast 1 line of output from git describe') end
      return resolve(lines[1])
    end)
  end)
end

return git
