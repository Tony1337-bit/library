--[[ lapi - Libre Application Programming Interface ]] 
local vector = require "vector"
local clipboard = require "gamesense/clipboard"
local base64 = require "gamesense/base64"
local _ui = ui
local wrapper = {}

local config_registry = {}

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
                if self:get() then callback_fn(self, ...) end
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

    function g:color_picker(name, default_color)
        local obj = new_object()
        if default_color == nil then default_color = {255, 255, 255, 255} end
        obj.reference = _ui.new_color_picker(self.tab, self.container, name,
                                             default_color)
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
    clipboard.set(prefix .. ":gamesense:" .. base64.encode(json.stringify(config)))
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
