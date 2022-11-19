local c3d_pipe = require("core.3D.stages.c3d_pipe")
local vertex   = require("core.3D.stages.vertex")

local name_lookup = {
    vertex   = vertex,
    c3d_pipe = c3d_pipe,
}

local modes = {
    function(t) return t end,
    function(s)
        local out = {}
        local n = 0
        for c in s:gmatch("[^%->]+") do
            n = n + 1
            local nam = c:gsub(" ","")
            local res = name_lookup[nam]
            if not res then error(nam.."is not a valid pipeline element.",2) end
            out[n] = res
        end
        return out
    end,
    function(...)
        return {...} 
    end
}

return function(BUS)

    return function()
        local pipe = plugin.new("c3d:module->pipe")
        
        function pipe.register_modules()
            local module_registry = c3d.registry.get_module_registry()
            local pipe_module     = module_registry:new_entry("pipe")

            pipe_module:set_entry(c3d.registry.entry("c3d_pipe"),function() return c3d_pipe    end)
            pipe_module:set_entry(c3d.registry.entry("vertex"), function()  return vertex      end)
            pipe_module:set_entry(c3d.registry.entry("finish"), function()  return finish      end)

            pipe_module:set_entry(c3d.registry.entry("set"),function(...)
                local t = {...}
                local mode = 1
                if type(t[1]) == "string" then
                    mode = 2
                elseif type(t[1]) == "function" then
                    mode = 3
                end

                BUS.pipeline = modes[mode](...)
            end)

            pipe_module:set_entry(c3d.registry.entry("add_type"),function(name,func)
                name_lookup[name] = func
            end)
        end

        pipe:register()
    end
end