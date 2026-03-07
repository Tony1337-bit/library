--[[ lapi - Libre Application Programming Interface ]] 
local vector =require "vector"
local ffi = require "ffi"
local clipboard = require "gamesense/clipboard"
local base64 = require "gamesense/base64"

local _ui = ui
local wrapper = {}
drag = {}
local config_registry = {}

local is_menu_visible = false

client.set_event_callback("paint_ui",function() 
    is_menu_visible = ui.is_menu_open() 
end)

local sw, sh = client.screen_size()

local screen_cx = math.floor(sw / 2)
local screen_cy = math.floor(sh / 2)

local snap_threshold = 8

local line_alpha_base = 40
local line_alpha_hit = 200
local drag_bg_alpha = 100

local function register_element(obj, tab, container, name)
    local key = tab .. ":" .. container .. ":" .. name
    config_registry[key] = obj
    return obj
end

local function new_object()
    local self = {}
    self.event_callbacks = {}

    function self:get(option)
        local element_type = self:type()

        if element_type == "multiselect" then
            local value = _ui.get(self.reference)
            if option then
                if type(value) == "table" then
                    for _, selected in ipairs(value) do
                        if selected == option then
                            return true
                        end
                    end
                end
                return false
            end
        end

        return _ui.get(self.reference)
    end

    function self:set(value) _ui.set(self.reference, value) end

    function self:visible(value)
        if self.visibility_callback then
            client.unset_event_callback("paint_ui", self.visibility_callback)
            self.visibility_callback = nil
        end

        if type(value) == "boolean" then
            _ui.set_visible(self.reference, value)
        elseif type(value) == "function" then
            self.visibility_callback = function()
                local result = value()
                _ui.set_visible(self.reference, result)
            end
            client.set_event_callback("paint_ui", self.visibility_callback)
        elseif type(value) == "table" and value.get then
            self.visibility_callback = function()
                local result = value:get()
                _ui.set_visible(self.reference, result)
            end
            client.set_event_callback("paint_ui", self.visibility_callback)
        elseif value == nil then
            return _ui.get_visible and _ui.get_visible(self.reference) or true
        end

        return self
    end

    function self:add_callback(event_name, callback_fn)
        local wrapper = function(...)
            local element_type = self:type()

            if element_type == "checkbox" then
                if self:get() then 
                    callback_fn(self, ...) 
                end
            else
                callback_fn(self, ...)
            end
        end

        self.event_callbacks[event_name] = wrapper
        client.set_event_callback(event_name, wrapper)

        return self
    end

    function self:callback(callback_fn)
        local wrapper = function() callback_fn(self) end
        _ui.set_callback(self.reference, wrapper)
        return self
    end

    function self:update(value, ...) _ui.update(self.reference, value, ...) end

    function self:disabled(state)
        if state ~= nil then
            _ui.set_enabled(self.reference, not state)
        else
            return not _ui.get(self.reference)
        end
    end

    function self:type() return _ui.type(self.reference) end

    function self:id() return self.reference end

    return self
end

function wrapper.group(tab, container)
    local g = {tab = tab, container = container}

    function g:switch(name, default)
        local obj = new_object()
        obj.reference = _ui.new_checkbox(self.tab, self.container, name)

        if default ~= nil then _ui.set(obj.reference, default) end

        return register_element(obj, self.tab, self.container, name)
    end

    function g:slider(name, min, max, default, show_tooltip, unit, scale,
                      tooltips)
        local obj = new_object()
        obj.reference = _ui.new_slider(self.tab, self.container, name, min, max,
                                       default or min, show_tooltip or true,
                                       unit or "", scale or 1.0, tooltips or {})
        return register_element(obj, self.tab, self.container, name)
    end

    function g:combo(name, ...)
        local obj = new_object()
        local options = {...}

        if type(options[1]) == 'table' then options = options[1] end

        obj.reference = _ui.new_combobox(self.tab, self.container, name,
                                         unpack(options))
        return register_element(obj, self.tab, self.container, name)
    end

    function g:selectable(name, ...)
        local obj = new_object()
        local options = {...}

        if type(options[1]) == 'table' then options = options[1] end

        obj.reference = _ui.new_multiselect(self.tab, self.container, name,
                                            unpack(options))
        return register_element(obj, self.tab, self.container, name)
    end

    function g:list(name, option)
        local obj = new_object()
        obj.reference = _ui.new_listbox(self.tab, self.container, name, option)
        return register_element(obj, self.tab, self.container, name)
    end

    function g:color_picker(name, r, g, b, a)
        local obj = new_object()
        obj.reference = _ui.new_color_picker(self.tab, self.container, name,
                                             r or 255, g or 255, b or 255,
                                             a or 255)
        return register_element(obj, self.tab, self.container, name)
    end

    function g:label(name)
        local obj = new_object()
        obj.reference = _ui.new_label(self.tab, self.container, name)
        return register_element(obj, self.tab, self.container, name)
    end

    function g:button(name, callback)
        local obj = new_object()
        obj.reference = _ui.new_button(self.tab, self.container, name, callback)
        return obj
    end

    function g:hotkey(name, ecx, edx)
        local obj = new_object()
        obj.reference = _ui.new_hotkey(self.tab, self.container, name, ecx,
                                       edx or 0)
        return register_element(obj, self.tab, self.container, name)
    end

    function g:input(name)
        local obj = new_object()
        obj.reference = _ui.new_textbox(self.tab, self.container, name)
        return register_element(obj, self.tab, self.container, name)
    end

    g.multicombo = g.selectable

    return g
end

function wrapper.find(tab, container, name)
    local refs = {_ui.reference(tab, container, name)}
    local objects = {}
    for _, ref in ipairs(refs) do
        local obj = new_object()
        obj.reference = ref
        table.insert(objects, obj)
    end
    return table.unpack(objects)
end

function wrapper.save()
    local config = {}

    for key, obj in pairs(config_registry) do
        local value = obj:get()

        if type(value) == "table" then
            local serialized = {}
            for k, v in pairs(value) do serialized[k] = v end
            config[key] = serialized
        else
            config[key] = value
        end
    end

    return config
end

function wrapper.load(config_data)
    if not config_data or type(config_data) ~= "table" then return false end

    for key, value in pairs(config_data) do
        local obj = config_registry[key]
        if obj then obj:set(value) end
    end

    return true
end

function wrapper.export(prefix)
    local config = wrapper.save()
    if type(prefix) ~= "string" then prefix = "eapi" end
    clipboard.set(prefix .. ":gamesense:" ..
                      base64.encode(json.stringify(config)))
end



function wrapper.import(config_string)
    if config_string == nil then
        config_string = clipboard.get()
        if not config_string or config_string == "" then
            utils.print("Config", "Clipboard is empty")
            return false, 0
        end
    end

    if type(config_string) == "table" then return wrapper.load(config_string) end

    if type(config_string) == "string" then
        local clean_string = config_string

        if string.find(config_string, ":gamesense:") then
            clean_string = string.match(config_string, ":gamesense:(.+)$")
        end

        if not clean_string then
            utils.print("Config", "Invalid config format")
            return false, 0
        end

        -- Decode and parse
        local success, decoded = pcall(base64.decode, clean_string)
        if not success then
            utils.print("Config", "Failed to decode base64")
            return false, 0
        end

        local success, config = pcall(json.parse, decoded)
        if not success then
            utils.print("Config", "Failed to parse JSON")
            return false, 0
        end

        return wrapper.load(config)
    end

    return false, 0
end

function wrapper.reset() config_registry = {} end

local mt = {
    __index = function(t, k)
        if wrapper[k] then return wrapper[k] end
        return _ui[k]
    end
}

lui = setmetatable({}, mt)

entity_c = {}

utils = {}

utils.get_vfunc = function(module_name, interface_name, index, typestring)
    local addr = client.create_interface(module_name, interface_name);
    assert(addr, string.format("%s::%s is invalid interface", module_name,
                               interface_name));

    local ctype = ffi.typeof(typestring);

    local vtable = ffi.cast("void***", addr);
    local vfunc = ffi.cast(ctype, vtable[0][index]);

    return function(...) return vfunc(vtable, ...); end
end

utils.get_velocity = function(ent)
    if not ent then return end

    local velocity_x = entity.get_prop(ent, "m_vecVelocity[0]")
    local velocity_y = entity.get_prop(ent, "m_vecVelocity[1]")
    local velocity_z = entity.get_prop(ent, "m_vecVelocity[2]")

    local velocity = vector(velocity_x, velocity_y, velocity_z)

    local speed = math.ceil(velocity:length2d())

    return speed
end

utils.print = function(name, ...)
    local message = {...}
    for k, v in ipairs(message) do message[k] = tostring(v); end
    local messages = table.concat(message, " ")
    local r, g, b, a = ui.get(ui.reference("misc", "settings", "menu color"))
    client.color_log(r, g, b, name .. " •\0")
    client.color_log(255, 255, 255, " » \0")
    client.color_log(217, 217, 217, messages)
end

utils.name = function(name)
    if name ~= nil then
        return name
    else
        return panorama.loadstring([[ return MyPersonaAPI.GetName() ]])()
    end
end

local clantag_index = 1
local clantag_last = 0
function utils.clantag(tag, speed)
    speed = speed or 0.5
    local now = totime(globals.tickcount())

    if now - clantag_last >= speed then
        clantag_last = now
        client.set_clan_tag(string.sub(tag, 0, clantag_index))

        clantag_index = clantag_index + 1
        if clantag_index > #tag then clantag_index = 1 end
    end
end

events = {}

local event_mt = {
    __call = function(self, bool, fn)
        local action = bool and client.set_event_callback or
                           client.unset_event_callback
        action(self[1], fn)
    end,
    set = function(self, fn) client.set_event_callback(self[1], fn) end,
    unset = function(self, fn) client.unset_event_callback(self[1], fn) end,
    fire = function(self, ...) client.fire_event(self[1], ...) end
}
event_mt.__index = event_mt

events = setmetatable({}, {
    __index = function(self, key)
        self[key] = setmetatable({key}, event_mt)
        return self[key]
    end
})

filesystem = {}
do
    local native = {
        ReadFile = utils.get_vfunc('filesystem_stdio.dll', 'VBaseFileSystem011',
                                   0,
                                   'int (__thiscall*)(void*, void*, int, void*)'),
        WriteFile = utils.get_vfunc('filesystem_stdio.dll',
                                    'VBaseFileSystem011', 1,
                                    'int (__thiscall*)(void*, void const*, int, void*)'),

        OpenFile = utils.get_vfunc('filesystem_stdio.dll', 'VBaseFileSystem011',
                                   2,
                                   'void* (__thiscall*)(void*, const char*, const char*, const char*)'),
        CloseFile = utils.get_vfunc('filesystem_stdio.dll',
                                    'VBaseFileSystem011', 3,
                                    'void (__thiscall*)(void*, void*)'),

        GetFileSize = utils.get_vfunc('filesystem_stdio.dll',
                                      'VBaseFileSystem011', 7,
                                      'unsigned int (__thiscall*)(void*, void*)'),
        FileExists = utils.get_vfunc('filesystem_stdio.dll',
                                     'VBaseFileSystem011', 10,
                                     'bool (__thiscall*)(void*, const char*, const char*)'),
        GetFileTime = utils.get_vfunc('filesystem_stdio.dll',
                                      'VBaseFileSystem011', 13,
                                      'int (__thiscall*)(void*, const char*, const char*)'),

        AddSearchPath = utils.get_vfunc('filesystem_stdio.dll',
                                        'VFileSystem017', 11,
                                        'void (__thiscall*)(void*, const char*, const char*, int)'),
        RemoveSearchPath = utils.get_vfunc('filesystem_stdio.dll',
                                           'VFileSystem017', 12,
                                           'bool (__thiscall*)(void*, const char*, const char*)'),

        RemoveFile = utils.get_vfunc('filesystem_stdio.dll', 'VFileSystem017',
                                     20,
                                     'void (__thiscall*)(void*, const char*, const char*)'),
        RenameFile = utils.get_vfunc('filesystem_stdio.dll', 'VFileSystem017',
                                     21,
                                     'bool (__thiscall*)(void*, const char*, const char*, const char*)'),
        CreateDirHierarchy = utils.get_vfunc('filesystem_stdio.dll',
                                             'VFileSystem017', 22,
                                             'void (__thiscall*)(void*, const char*, const char*)'),
        IsDirectory = utils.get_vfunc('filesystem_stdio.dll', 'VFileSystem017',
                                      23,
                                      'bool (__thiscall*)(void*, const char*, const char*)'),

        FindFirst = utils.get_vfunc('filesystem_stdio.dll', 'VFileSystem017',
                                    32,
                                    'const char* (__thiscall*)(void*, const char*, int*)'),
        FindNext = utils.get_vfunc('filesystem_stdio.dll', 'VFileSystem017', 33,
                                   'const char* (__thiscall*)(void*, int)'),
        FindIsDirectory = utils.get_vfunc('filesystem_stdio.dll',
                                          'VFileSystem017', 34,
                                          'bool (__thiscall*)(void*, int)'),
        FindClose = utils.get_vfunc('filesystem_stdio.dll', 'VFileSystem017',
                                    35, 'void (__thiscall*)(void*, int)'),

        GetGameDirectory = utils.get_vfunc('engine.dll', 'VEngineClient014', 36,
                                           'const char*(__thiscall*)(void*)')
    }

    local modes = {
        ['r'] = 'r',
        ['w'] = 'w',
        ['a'] = 'a',
        ['r+'] = 'r+',
        ['w+'] = 'w+',
        ['a+'] = 'a+',
        ['rb'] = 'rb',
        ['wb'] = 'wb',
        ['ab'] = 'ab',
        ['rb+'] = 'rb+',
        ['wb+'] = 'wb+',
        ['ab+'] = 'ab+'
    }

    filesystem.read = function(self)
        local size = self:get_size()
        local array = ffi.new('char[?]', size + 1)
        native.ReadFile(array, size, self.handle)
        return ffi.string(array, size)
    end
    filesystem.write = function(self, ...)
        local string = tostring(table.concat({...}))
        native.WriteFile(string, string:len(), self.handle)
    end

    filesystem.open = function(path, mode, path_id)
        if not modes[mode] then return nil end

        return setmetatable({
            path = path,
            mode = mode,
            path_id = path_id,
            handle = native.OpenFile(path, mode, path_id)
        }, {__index = file})
    end
    filesystem.close = function(self) native.CloseFile(self.handle) end

    filesystem.get_size = function(self)
        return native.GetFileSize(self.handle)
    end
    filesystem.exists = function(path, path_id)
        return native.FileExists(path, path_id)
    end
    filesystem.get_time = function(path, path_id)
        return native.GetFileTime(path, path_id)
    end

    filesystem.add_search_path = function(path, path_id, type)
        native.AddSearchPath(path, path_id, type)
    end
    filesystem.remove_search_path = function(path, path_id)
        native.RemoveSearchPath(path, path_id)
    end

    filesystem.remove = function(path, path_id)
        native.RemoveFile(path, path_id)
    end
    filesystem.rename = function(old_path, new_path, path_id)
        native.RenameFile(old_path, new_path, path_id)
    end
    filesystem.create_directory = function(path, path_id)
        native.CreateDirHierarchy(path, path_id)
    end
    filesystem.is_directory = function(path, path_id)
        return native.IsDirectory(path, path_id)
    end

    filesystem.find_first = function(path)
        local handle = ffi.new('int[1]')
        local found_file = native.FindFirst(path, handle)
        if found_file == ffi.NULL then return nil end
        return handle, ffi.string(found_file)
    end
    filesystem.find_next = function(handle)
        local found_file = native.FindNext(handle)
        if found_file == ffi.NULL then return nil end
        return ffi.string(found_file)
    end
    filesystem.find_is_directory = function(handle)
        return native.FindIsDirectory(handle)
    end
    filesystem.find_close = function(handle) native.FindClose(handle) end

    filesystem.get_game_directory = function()
        return ffi.string(native.GetGameDirectory()):sub(1, -5)
    end
    function filesystem:list_files(path)
        local names = {}
        local handle, name = self.find_first(
                                 ('%s\\%s\\*'):format(self.get_game_directory(),
                                                      path))
        if not handle then return names end

        repeat
            if not self.find_is_directory(handle[0]) then
                table.insert(names, name)
            end
            name = self.find_next(handle[0])
        until not name

        self.find_close(handle[0])
        return names
    end

end


drag.list = {}
drag.windows = {}

drag.__index = drag

drag.register = function(position, size, global_name, ins_function,show_symmetry)
    local data = {
        size = size,
        position = {x = ui.get(position[1]), y = ui.get(position[2])},

        is_dragging = false,
        drag_position = {x = 0, y = 0},

        global_name = global_name,
        ins_function = ins_function,
        show_symmetry = show_symmetry or false,

        ui_callbacks = {x = position[1], y = position[2]}
    }

    table.insert(drag.windows, data)
    return setmetatable(data, drag)
end

function drag:limit_positions()
    if self.position.x < 0 then self.position.x = 0 end
    if self.position.x + self.size.x >= sw - 1 then
        self.position.x = sw - self.size.x - 1
    end
    if self.position.y < 0 then self.position.y = 0 end
    if self.position.y + self.size.y >= sh - 1 then
        self.position.y = sh - self.size.y - 1
    end
end

function drag:is_in_area(mx, my)
    return
        mx >= self.position.x and mx <= self.position.x + self.size.x and my >=
            self.position.y and my <= self.position.y + self.size.y
end

function drag:check_symmetry_hits()
    local cx = self.position.x + self.size.x / 2
    local cy = self.position.y + self.size.y / 2

    local hit_v = math.abs(cx - screen_cx) <= snap_threshold
    local hit_h = math.abs(cy - screen_cy) <= snap_threshold

    return hit_v, hit_h
end

-- draws full-screen symmetry lines, highlights if any dragging window collides
function drag.draw_symmetry_lines()
    local hit_v, hit_h = false, false
    -- check all currently-dragging windows
    if not is_menu_visible then
        return
    end
    for _, win in pairs(drag.windows) do
        if win.show_symmetry and win.is_dragging then
            local v, h = drag.check_symmetry_hits(win)
            if v then hit_v = true end
            if h then hit_h = true end
        end
    end

    local alpha_v = hit_v and line_alpha_hit or line_alpha_base
    local alpha_h = hit_h and line_alpha_hit or line_alpha_base

    renderer.line(screen_cx, 0, screen_cx, sh, 255, 255, 255, alpha_v)
    renderer.line(0, screen_cy, sw, screen_cy, 255, 255, 255, alpha_h)
end

function drag:update(...)
    if is_menu_visible == true then
        local mx, my = ui.mouse_position()
        local in_area = self:is_in_area(mx, my)

        local list = drag.list
        local lmb_down = client.key_state(0x1)
        local target_free = (list.target == nil or list.target == "" or
                                list.target == self.global_name)

        if (in_area or self.is_dragging) and lmb_down and target_free then
            list.target = self.global_name

            if not self.is_dragging then
                self.is_dragging = true
                self.drag_position = {
                    x = mx - self.position.x,
                    y = my - self.position.y
                }
            else
                self.position.x = mx - self.drag_position.x
                self.position.y = my - self.drag_position.y
                self:limit_positions()

                ui.set(self.ui_callbacks.x, math.floor(self.position.x))
                ui.set(self.ui_callbacks.y, math.floor(self.position.y))
            end
        elseif not lmb_down then
            list.target = ""
            self.is_dragging = false
            self.drag_position = {x = 0, y = 0}
        end

        -- dark overlay while this window is being dragged
        if self.is_dragging then
            renderer.rectangle(0, 0, sw, sh, 0, 0, 0, drag_bg_alpha)
        end
        drag.draw_symmetry_lines()
    end

    self.ins_function(self, ...)
end

drag.on_config_load = function()
    for _, point in pairs(drag.windows) do
        point.position = {
            x = ui.get(point.ui_callbacks.x),
            y = ui.get(point.ui_callbacks.y)
        }
    end
end

client.set_event_callback("setup_command", function(cmd)
    local org = {
        in_attack = cmd.in_attack,
        in_attack2 = cmd.in_attack2,
        in_use = cmd.in_use
    }

    if is_menu_visible == true then
        cmd.in_attack = 0
        cmd.in_attack2 = 0
        cmd.in_use = 0
    else
        cmd.in_attack = org.in_attack
        cmd.in_attack2 = org.in_attack2
        cmd.in_use = org.in_use
    end
end)
