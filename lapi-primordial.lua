-- LapI - Primordial 
local clipboard = require "clipboard"
local json = require "json"
local base64 = require "base64"
local _menu = menu
local wrapper = {}
local callback = {}
local config_registry = {}

local DEBUG_MODE = false

local function log(...)
    if DEBUG_MODE then
        local args = {...}
        local msg = "[LUI] "
        for i, v in ipairs(args) do
            msg = msg .. tostring(v)
            if i < #args then msg = msg .. " " end
        end
        print(msg)
    end
end

local function safe_string(str)
    if type(str) == "string" then return str end
    return tostring(str)
end

local function register_element(obj, container, name)
    if not obj or not container or not name then
        error("register_element: Invalid parameters")
    end

    local key = container .. ":" .. name
    if config_registry[key] then
        log("Warning: Overwriting existing element:", key)
    end

    config_registry[key] = obj
    return obj
end

local function new_object()
    local self = {}

    function self:get()
        if not self.reference then
            error("Element not properly initialized")
        end
        return self.reference:get()
    end

    self._callbacks = {}
    self._events = {}
    self._last_value = nil
    self._visibility_mode = nil
    self._visibility_value = nil
    self._visibility_registered = false
    self._change_registered = false

    function self:_initialize()
        if self.reference then self._last_value = self.reference:get() end
    end

    function self:set(value)
        if not self.reference then
            error("Cannot set value: Element not initialized")
        end
        self.reference:set(value)
        return self
    end

    function self:visible(value)
        self._visibility_mode = type(value)
        self._visibility_value = value

        if not self._visibility_registered then
            self._visibility_registered = true

            callbacks.add(e_callbacks.PAINT, function()
                if not self.reference then return end

                local visible = false
                if self._visibility_mode == "boolean" then
                    visible = self._visibility_value
                elseif self._visibility_mode == "function" then
                    visible = self._visibility_value()
                elseif type(self._visibility_value) == "table" and
                    self._visibility_value.get then
                    visible = self._visibility_value:get()
                end

                self.reference:set_visible(visible)
            end)
        end

        return self
    end

    function self:add_callback(event_name, fn)
        local event_enum = e_callbacks[string.upper(event_name)]
        if not event_enum then
            error("Invalid event: " .. tostring(event_name))
        end

        if not self._events[event_enum] then
            self._events[event_enum] = {}

            callbacks.add(event_enum, function(...)
                for _, callback_fn in ipairs(self._events[event_enum]) do
                    -- checkbox gating
                    local val = self:get()
                    if type(val) == "boolean" then
                        if val then
                            callback_fn(self, ...)
                        end
                    else
                        callback_fn(self, ...)
                    end
                end
            end)
        end

        table.insert(self._events[event_enum], fn)
        return self
    end

    function self:callback(fn)
        if type(fn) ~= "function" then
            error("Callback must be a function")
        end

        table.insert(self._callbacks, fn)

        if not self._change_registered then
            self._change_registered = true

            callbacks.add(e_callbacks.PAINT, function()
                if not self.reference then return end

                local current = self.reference:get()

                if current ~= self._last_value then
                    self._last_value = current

                    for _, cb in ipairs(self._callbacks) do
                        local success, err = pcall(function()
                            -- If boolean (checkbox), only run when true
                            if type(current) == "boolean" then
                                if current then
                                    cb(self)
                                end
                            else
                                cb(self)
                            end
                        end)

                        if not success then
                            log("Error in change callback:", err)
                        end
                    end
                end
            end)
        end

        return self
    end

    function self:color(name) return self.reference:add_color_picker(name) end

    function self:hotkey(name) return self.reference:add_keybind(name) end

    function self:id() return self.reference end

    return self
end

function wrapper.group(container, columm)
    if not container then error("group: container name required") end

    local g = {container = container, columm = columm or 0}

    menu.set_group_column(container, columm)

    local success, err = pcall(menu.set_group_column, container, g.columm)
    if not success then log("Warning: Could not set group column:", err) end

    function g:switch(name, default)
        if not name then error("switch: name required") end

        local obj = new_object()
        obj._container = container
        obj._name = name
        obj.reference = _menu.add_checkbox(container, name, default or false)
        obj:_initialize()

        -- checkbox‑only color picker
        function obj:color(sub_name, default_color, has_alpha)
            sub_name = sub_name or (self._name .. " color")

            local picker = self.reference:add_color_picker(sub_name,
                                                           default_color or
                                                               {
                    255, 255, 255, 255
                }, has_alpha) -- color_picker_t [page:0][page:1]

            local cobj = new_object()
            cobj._container = self._container
            cobj._name = sub_name
            cobj.reference = picker
            cobj:_initialize()

            return register_element(cobj, self._container, sub_name)
        end

        -- checkbox‑only hotkey
        function obj:hotkey(sub_name, default_key)
            sub_name = sub_name or (self._name .. " hotkey")

            local keyb = self.reference:add_keybind(sub_name, default_key) -- keybind_t [page:0]

            local kobj = new_object()
            kobj._container = self._container
            kobj._name = sub_name
            kobj.reference = keyb
            kobj:_initialize()

            return register_element(kobj, self._container, sub_name)
        end

        return register_element(obj, container, name)
    end

    function g:list(name, items)
        if not name then error("list: name required") end
        if not items or type(items) ~= "table" then
            error("list: items table required")
        end

        local obj = new_object()
        obj.reference = _menu.add_list(container, name, items)
        obj:_initialize()
        return register_element(obj, container, name)
    end

    function g:slider(name, min, max, step, precision, suffix)
        if not name then error("slider: name required") end

        local obj = new_object()
        obj.reference =_menu.add_slider(container, name, min, max, step, precision or 0, suffix or "")

        obj:_initialize()
        return register_element(obj, container, name)
    end

    function g:combo(name, items)
        if not name then error("combo: name required") end
        if not items or type(items) ~= "table" then
            error("combo: items table required")
        end

        local obj = new_object()
        obj.reference = _menu.add_selection(container, name, items)
        obj:_initialize()
        return register_element(obj, container, name)
    end

    function g:textbox(name)
        if not name then error("textbox: name required") end

        local obj = new_object()
        obj.reference = _menu.add_text_input(container, name)
        obj:_initialize()
        return register_element(obj, container, name)
    end

    function g:button(name, callback_fn)
        if not name then error("button: name required") end

        local obj = new_object()
        obj.reference = _menu.add_button(container, name,
                                         callback_fn or function() end)
        return obj
    end

    function g:label(text)
        if not text then error("label: text required") end

        local obj = new_object()
        obj.reference = _menu.add_text(container, text)
        return obj
    end

    function g:selectable(name, items)
        if not name then error("selectable: name required") end
        if not items or type(items) ~= "table" then
            error("selectable: items table required")
        end

        local obj = new_object()
        obj.reference = _menu.add_multi_selection(container, name, items)
        return register_element(obj, container, name)
    end

    return g
end

function wrapper.save()
    local config = {}
    local count = 0

    for key, obj in pairs(config_registry) do
        if obj and obj.get then
            local success, val = pcall(obj.get, obj)
            if success then
                if type(val) == "table" then
                    local copy = {}
                    for k, v in pairs(val) do copy[k] = v end
                    config[key] = copy
                else
                    config[key] = val
                end
                count = count + 1
            else
                log("Error getting value for:", key)
            end
        end
    end

    log("Saved", count, "config values")
    return config
end

function wrapper.load(config_data)
    if not config_data or type(config_data) ~= "table" then
        log("Invalid config table")
        return false, 0
    end

    local loaded_count = 0
    local failed_count = 0

    for key, value in pairs(config_data) do
        local obj = config_registry[key]
        if obj and obj.set then
            local success, err = pcall(obj.set, obj, value)
            if success then
                loaded_count = loaded_count + 1
            else
                log("Error setting value for", key, ":", err)
                failed_count = failed_count + 1
            end
        else
            log("No UI element registered for key:", key)
            failed_count = failed_count + 1
        end
    end

    log("Loaded", loaded_count, "values,", failed_count, "failed")
    return true, loaded_count
end

-- Export config to clipboard
function wrapper.export(prefix)
    local config = wrapper.save()
    prefix = prefix or "lui"

    local success, json_str = pcall(json.encode, config)
    if not success then
        log("Failed to encode config to JSON:", json_str)
        return false
    end

    local success, encoded = pcall(base64.encode, json_str)
    if not success then
        log("Failed to encode to base64:", encoded)
        return false
    end

    local config_string = prefix .. ":primordial:" .. encoded
    clipboard.set(config_string)
    log("Exported config to clipboard")
    print("[Config] Exported to clipboard!")
    return true
end

function wrapper.import(config_string)
    if config_string == nil then
        config_string = clipboard.get()
        if not config_string or config_string == "" then
            log("Clipboard is empty")
            print("[Config] Clipboard is empty!")
            return false, 0
        end
    end

    if type(config_string) == "table" then return wrapper.load(config_string) end

    if type(config_string) ~= "string" then
        log("Invalid config type:", type(config_string))
        return false, 0
    end

    local clean_string = config_string

    if string.find(config_string, ":primordial:") then
        clean_string = string.match(config_string, ":primordial:(.+)$")
    end

    if not clean_string or clean_string == "" then
        log("Invalid config format - empty after extraction")
        print("[Config] Invalid config format!")
        return false, 0
    end

    local success, decoded = pcall(base64.decode, clean_string)
    if not success then
        log("Failed to decode base64:", decoded)
        print("[Config] Failed to decode config!")
        return false, 0
    end

    local success, config = pcall(json.decode, decoded)
    if not success then
        log("Failed to parse JSON:", config)
        print("[Config] Failed to parse config!")
        return false, 0
    end

    local success, count = wrapper.load(config)
    if success then print("[Config] Loaded " .. count .. " settings!") end
    return success, count
end

-- Reset config registry
function wrapper.reset()
    config_registry = {}
    log("Config registry reset")
end

-- Get config registry
function wrapper.get_registry() return config_registry end

-- Count registered elements
function wrapper.count()
    local count = 0
    for _ in pairs(config_registry) do count = count + 1 end
    return count
end

-- Enable/disable debug mode
function wrapper.set_debug(enabled)
    DEBUG_MODE = enabled
    log("Debug mode:", enabled)
end

-- Export config as readable JSON string (for copying)
function wrapper.export_json()
    local config = wrapper.save()
    local success, json_str = pcall(json.encode, config)
    if not success then
        log("Failed to encode config to JSON")
        return nil
    end
    return json_str
end

-- Import config from JSON string
function wrapper.import_json(json_str)
    if not json_str or json_str == "" then
        log("Empty JSON string")
        return false, 0
    end

    local success, config = pcall(json.parse, json_str)
    if not success then
        log("Failed to parse JSON:", config)
        return false, 0
    end

    return wrapper.load(config)
end

-- Create metatable for seamless integration with menu
local mt = {
    __index = function(t, k)
        if wrapper[k] then return wrapper[k] end
        return _menu[k]
    end
}

callbacks.add(e_callbacks.PAINT, function() end)

lui = setmetatable({}, mt)

