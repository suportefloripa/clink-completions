
-- TODO: deduplicate get_git_dir method
-- TODO: deduplicate get_git_branch method
-- TODO: cache config based on some modification indicator (system mtime, hash)

-- this code is stolen from https://github.com/Dynodzzo/Lua_INI_Parser/blob/master/LIP.lua
-- Resolve licensing issues before exposing
local function load_ini(fileName)
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.')
    local file = io.open(fileName, 'r')
    if not file then return nil end

    local data = {};
    local section;
    for line in file:lines() do
        local tempSection = line:match('^%[([^%[%]]+)%]$');
        if tempSection then
            section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
            data[section] = data[section] or {}
        end

        local param, value = line:match('^%s-([%w|_]+)%s-=%s+(.+)$')
        if(param and value ~= nil)then
            if(tonumber(value))then
                value = tonumber(value);
            elseif(value == 'true')then
                value = true;
            elseif(value == 'false')then
                value = false;
            end
            if(tonumber(param))then
                param = tonumber(param);
            end
            data[section][param] = value
        end
    end
    file:close();
    return data;
end

local git = {}
git.get_config = function (git_dir, section, param)
    if not git_dir then return nil end
    if (not param) or (not section) then return nil end

    local git_config = load_ini(git_dir..'/config')
    if not git_config then return nil end

    return git_config[section] and git_config[section][param] or nil
end


---
 -- Resolves closest directory location for specified directory.
 -- Navigates subsequently up one level and tries to find specified directory
 -- @param  {string} path    Path to directory will be checked. If not provided
 --                          current directory will be used
 -- @param  {string} dirname Directory name to search for
 -- @return {string} Path to specified directory or nil if such dir not found
local function get_dir_contains(path, dirname)

    -- return parent path for specified entry (either file or directory)
    local function pathname(path)
        local prefix = ""
        local i = path:find("[\\/:][^\\/:]*$")
        if i then
            prefix = path:sub(1, i-1)
        end
        return prefix
    end

    -- Navigates up one level
    local function up_one_level(path)
        if path == nil then path = '.' end
        if path == '.' then path = clink.get_cwd() end
        return pathname(path)
    end

    -- Checks if provided directory contains git directory
    local function has_specified_dir(path, specified_dir)
        if path == nil then path = '.' end
        local found_dirs = clink.find_dirs(path..'/'..specified_dir)
        if #found_dirs > 0 then return true end
        return false
    end

    -- Set default path to current directory
    if path == nil then path = '.' end

    -- If we're already have .git directory here, then return current path
    if has_specified_dir(path, dirname) then
        return path..'/'..dirname
    else
        -- Otherwise go up one level and make a recursive call
        local parent_path = up_one_level(path)
        if parent_path == path then
            return nil
        else
            return get_dir_contains(parent_path, dirname)
        end
    end
end

-- adapted from from clink-completions' git.lua
local function get_git_dir(path)

    -- return parent path for specified entry (either file or directory)
    local function pathname(path)
        local prefix = ""
        local i = path:find("[\\/:][^\\/:]*$")
        if i then
            prefix = path:sub(1, i-1)
        end
        return prefix
    end

    -- Checks if provided directory contains git directory
    local function has_git_dir(dir)
        return #clink.find_dirs(dir..'/.git') > 0 and dir..'/.git'
    end

    local function has_git_file(dir)
        local gitfile = io.open(dir..'/.git')
        if not gitfile then return false end

        local git_dir = gitfile:read():match('gitdir: (.*)')
        gitfile:close()

        return git_dir and dir..'/'..git_dir
    end

    -- Set default path to current directory
    if not path or path == '.' then path = clink.get_cwd() end

    -- Calculate parent path now otherwise we won't be
    -- able to do that inside of logical operator
    local parent_path = pathname(path)

    return has_git_dir(path)
        or has_git_file(path)
        -- Otherwise go up one level and make a recursive call
        or (parent_path ~= path and get_git_dir(parent_path) or nil)
end

---
 -- Find out current branch
 -- @return {nil|git branch name}
---
local function get_git_branch(git_dir)
    local git_dir = git_dir or get_git_dir()

    -- If git directory not found then we're probably outside of repo
    -- or something went wrong. The same is when head_file is nil
    local head_file = git_dir and io.open(git_dir..'/HEAD')
    if not head_file then return end

    local HEAD = head_file:read()
    head_file:close()

    -- if HEAD matches branch expression, then we're on named branch
    -- otherwise it is a detached commit
    local branch_name = HEAD:match('ref: refs/heads/(.+)')
    return branch_name or 'HEAD detached at '..HEAD:sub(1, 7)
end

local function git_prompt_filter()

    local git_dir = get_git_dir()
    if not git_dir then return false end

    -- if we're inside of git repo then try to detect current branch
    local branch = get_git_branch(git_dir)
    if not branch then return false end

    -- for remote and ref resolution algorithm see https://git-scm.com/docs/git-push
    -- print (git.get_config(git_dir, 'branch "'..branch..'"', 'remote'))
    local remote_to_push = git.get_config(git_dir, 'branch "'..branch..'"', 'remote') or 'origin'
    local remote_ref = git.get_config(git_dir, 'remote "'..remote_to_push..'"', 'push') or
        git.get_config(git_dir, 'push', 'default') or branch

    clink.prompt.value = string.gsub(clink.prompt.value, '{git}',
        '{git} => ('..remote_to_push..'/'..remote_ref..')')

    return false
end

clink.prompt.register_filter(git_prompt_filter, 45)
