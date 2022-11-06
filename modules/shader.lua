local matmul = require("core.3D.math.matmul")

local RANDOM,MAX,MIN,CEIL = math.random,math.max,math.min,math.ceil

return function(BUS)

    return function()
        local shader = plugin.new("c3d:shader")

        function shader.register_modules()
            local module_registry = c3d.registry.get_module_registry()
            local shader_module   = module_registry:new_entry("shader")
            
            local default = {}
            local vertex = {}
            local frag = {}

            function default.vertex(new_vertice,properties,scale,rot,pos,camera,per)
                local scaled_vertice     = matmul(new_vertice,scale)
                local rotated_vertice    = matmul(scaled_vertice,rot)
                local translated_vertice = matmul(rotated_vertice,pos)
                local camera_transform
                if camera.transform then
                    camera_transform = matmul(translated_vertice,camera.transform)
                else
                    camera_transform = matmul(matmul(translated_vertice,camera.position),camera.rotation)
                end
                return matmul(camera_transform,per)
            end

            function default.frag(frag)
                if frag.texture then
                    local tex = frag.tex
                    local w = tex.w
                    local h = tex.h

                    local z = frag.z_correct
                    local x = MAX(1,MIN(CEIL(frag.tx*z*w),w))
                    local y = MAX(1,MIN(CEIL(frag.ty*z*h),h))

                    return frag.texture[h-y+1][x]
                end

                return frag.color or colors.red
            end

            function default.geometry(triangle)
                return triangle
            end

            function frag.noise()
                return 2^(RANDOM(0,1)*15)
            end

            function vertex.skybox(new_vertice,properties,scale,rot,pos,camera,per)
                local ct = camera.transform

                local scaled_vertice     = matmul(new_vertice,scale)
                local rotated_vertice    = matmul(scaled_vertice,rot)
                local camera_transform
                if ct then
                    camera_transform = matmul(rotated_vertice,{
                        ct[1],ct[2],ct[3],ct[4],
                        ct[5],ct[6],ct[7],ct[8],
                        ct[9],ct[10],ct[11],ct[12],
                        0,0,0,1
                    })
                else
                    camera_transform = matmul(matmul(rotated_vertice,camera.position),camera.rotation)
                end
                return matmul(camera_transform,per)
            end

            shader_module:set_entry(c3d.registry.entry("default"),default)
            shader_module:set_entry(c3d.registry.entry("vertex") ,vertex)
            shader_module:set_entry(c3d.registry.entry("frag")   ,frag)
        end

        shader:register()
    end
end