local frustum_handle  = require("core.3D.geometry.clip_cull_frustum")
local fragment_shader = require("core.3D.stages.fragment_shader")

return function(object,prev,geo,prop,efx,out,BUS)
    local on = out.n
    local out_tris = out.tris

    local shader = efx.fs

    local tris = geo.tris

    local t_index = 0
    for i=1,#tris,3 do
        t_index = t_index + 1
        local a = prev[tris[i]]
        local b = prev[tris[i+1]]
        local c = prev[tris[i+2]]

        on = frustum_handle(object,out_tris,a,b,c,on,fragment_shader(shader),t_index)
    end

    out.n = on
end