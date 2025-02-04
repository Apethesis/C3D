local CEIL,MAX,MIN,ABS,SQRT,pairs = math.ceil,math.max,math.min,math.abs,math.sqrt,pairs

local int_y  = require("core.3D.math.interpolate_y")
local get_t  = require("core.3D.math.get_interpolant")
local int_uv = require("core.3D.math.interpolate_uv")

local barycentric_coordinates = require("core.3D.geometry.bary_coords")
local int_vertex              = require("core.3D.geometry.interpolate_vertex")

local memory_manager = require("core.mem_manager")

local empty_table = {}
local EMPTY_FRAGMENT = {}

return {build=function(BUS)

    BUS.log("  - Inicialized triangle rasterizer",BUS.log.info)

    local graphics_bus = BUS.graphics

    local mem_handle = memory_manager.get(BUS)

    local interpolate_vertex = int_vertex.init(BUS)

    local function draw_flat_top_triangle(fs,object,v0,v1,v2,tex,o1,o2,o3,fragment,w,h,stv1,stv2,stv3)
        local mem_handle = mem_handle
        local v0x,v0y = v0[1],v0[2]
        local v1x,v1y = v1[1],v1[2]
        local v2x,v2y = v2[1],v2[2]
        
        local v0u,v0v = v0[5],v0[6]
        local v1u,v1v = v1[5],v1[6]
        local v2u,v2v = v2[5],v2[6]
        local o1frag,o2frag,o3frag = o1.frag,o2.frag,o3.frag
        local o13,o14  = o1[3],o1[4]
        local m0 = (v2x - v0x) / (v2y - v0y)
        local m1 = (v2x - v1x) / (v2y - v1y)
        local y_start = MAX(CEIL(v0y - 0.5),1)
        local y_end   = MIN(CEIL(v2y - 0.5)-1,h)

        local C = object.color
        local TPIX = (tex or empty_table).pixels
        local STNF = object.instantiate_fragment
    
        for y=y_start,y_end do
            local px0 = m0 * (y + 0.5 - v0y) + v0x
            local px1 = m1 * (y + 0.5 - v1y) + v1x
            local x_start = MAX(CEIL(px0 - 0.5),1)
            local x_end   = MIN(CEIL(px1 - 0.5),w)
    
            local sx_start = int_y(o1,o2,y)
            local sx_end   = int_y(o1,o3,y)
            local t1 = get_t(o1,o2,sx_start,y)
            local t2 = get_t(o1,o3,sx_end,y)
            local w1 = (1 - t1) * o13 + t1 * o2[3]
            local w2 = (1 - t2) * o13 + t2 * o3[3]
            local z1 = (1 - t1) * o14 + t1 * o2[4]
            local z2 = (1 - t2) * o14 + t2 * o3[4]

            local temp_interpolants1
            local temp_interpolants2
            local naming
            local num = 0
            local make_fragment = false
            if o1frag then for k,v in pairs(o1frag) do
                temp_interpolants1 = mem_handle.get_table()
                temp_interpolants2 = mem_handle.get_table()
                naming = mem_handle.get_table()
                if o2frag[k] and o3frag[k] then
                    make_fragment = true
                    num = num + 1
                    temp_interpolants1[k] = (1 - t1) * v + t1 * o2frag[k]
                    temp_interpolants2[k] = (1 - t2) * v + t2 * o3frag[k]
                    naming[num] = k
                end
            end end
    
            for x=x_start,x_end do
                local bary_a,bary_b,bary_c = barycentric_coordinates(x,y,v0x,v0y,v1x,v1y,v2x,v2y)
    
                local div = sx_end - sx_start
                local t3 = (x - sx_start) / ((div == 0) and 5e-10 or div)
    
                local z = 1/((1 - t3) * w1 + t3 * w2)

                local fragment_shader_data = STNF and mem_handle.get_table() or EMPTY_FRAGMENT
                fragment_shader_data.texture   = TPIX
                fragment_shader_data.tex       = tex
                fragment_shader_data.color     = C
                fragment_shader_data.x         = x
                fragment_shader_data.y         = y
                fragment_shader_data.z_correct = z
                fragment_shader_data.v1        = stv1
                fragment_shader_data.v2        = stv2
                fragment_shader_data.v3        = stv3


                local frag_data
                if make_fragment then frag_data = mem_handle.get_table() end
                for i=1,num do
                    local nm = naming[i]
                    frag_data[nm] = ((1 - t3) * temp_interpolants1[nm] + t3 * temp_interpolants2[nm])*z
                end
                fragment_shader_data.data = frag_data

                if tex then
                    local thisu,thisv = int_uv(bary_a,bary_b,bary_c,v0u,v0v,v1u,v1v,v2u,v2v)
                    fragment_shader_data.tx,fragment_shader_data.ty = thisu,thisv

                    local bary_aright,bary_bright,bary_cright = barycentric_coordinates(x+1  ,y,v0x,v0y,v1x,v1y,v2x,v2y)
                    local bary_adown,bary_bdown,bary_cdown    = barycentric_coordinates(x,y+1,v0x,v0y,v1x,v1y,v2x,v2y)

                    local uright,vright = int_uv(bary_aright,bary_bright,bary_cright,v0u,v0v,v1u,v1v,v2u,v2v)
                    local udown ,vdown  = int_uv(bary_adown,bary_bdown,bary_cdown,v0u,v0v,v1u,v1v,v2u,v2v)

                    local L = MAX(
                        SQRT((ABS(thisu-uright)*tex.w)^2+(ABS(thisv-vright)*tex.h)^2),
                        SQRT((ABS(thisv-vdown) *tex.h)^2+(ABS(thisu-udown) *tex.w)^2)
                    )

                    fragment_shader_data.mipmap_level = L
                else
                    fragment_shader_data.mipmap_level = nil
                    fragment_shader_data.tx,fragment_shader_data.ty = nil,nil
                end
    
                fragment(x,y,(1 - t3) * z1 + t3 * z2,
                    fs(fragment_shader_data)
                )
            end
        end
    end
    
    local function draw_flat_bottom_triangle(fs,object,v0,v1,v2,tex,o1,o2,o3,fragment,w,h,stv1,stv2,stv3)
        local mem_handle = mem_handle
        local v0x,v0y = v0[1],v0[2]
        local v1x,v1y = v1[1],v1[2]
        local v2x,v2y = v2[1],v2[2]

        local v0u,v0v = v0[5],v0[6]
        local v1u,v1v = v1[5],v1[6]
        local v2u,v2v = v2[5],v2[6]
        local o1frag,o2frag,o3frag = o1.frag,o2.frag,o3.frag
        local o13,o14  = o1[3],o1[4]
        local m0 = (v1x - v0x) / (v1y - v0y)
        local m1 = (v2x - v0x) / (v2y - v0y)
        local y_start = MAX(CEIL(v0y - 0.5),1)
        local y_end   = MIN(CEIL(v2y - 0.5)-1,h)

        local C = object.color
        local TPIX = (tex or empty_table).pixels
        local STNF = object.instantiate_fragment
    
        for y=y_start,y_end do
            local px0 = m0 * (y + 0.5 - v0y) + v0x
            local px1 = m1 * (y + 0.5 - v0y) + v0x
            local x_start = MAX(CEIL(px0 - 0.5),1)
            local x_end   = MIN(CEIL(px1 - 0.5),w)
    
            local sx_start = int_y(o1,o2,y)
            local sx_end   = int_y(o1,o3,y)
            local t1 = get_t(o1,o2,sx_start,y)
            local t2 = get_t(o1,o3,sx_end,y)
            local w1 = (1 - t1) * o13 + t1 * o2[3]
            local w2 = (1 - t2) * o13 + t2 * o3[3]
            local z1 = (1 - t1) * o14 + t1 * o2[4]
            local z2 = (1 - t2) * o14 + t2 * o3[4]

            local temp_interpolants1
            local temp_interpolants2
            local naming
            local make_fragment = false
            local num = 0
            if o1frag then for k,v in pairs(o1frag) do
                temp_interpolants1 = mem_handle.get_table()
                temp_interpolants2 = mem_handle.get_table()
                naming = mem_handle.get_table()
                if o2frag[k] and o3frag[k] then
                    make_fragment = true
                    num = num + 1
                    temp_interpolants1[k] = (1 - t1) * v + t1 * o2frag[k]
                    temp_interpolants2[k] = (1 - t2) * v + t2 * o3frag[k]
                    naming[num] = k
                end
            end end
    
            for x=x_start,x_end do
                local bary_a,bary_b,bary_c =  barycentric_coordinates(x,y,v0x,v0y,v1x,v1y,v2x,v2y)
    
                local div = sx_end - sx_start
                local t3 = (x - sx_start) / ((div == 0) and 5e-10 or div)
    
                local z = 1/((1 - t3) * w1 + t3 * w2)

                local fragment_shader_data = STNF and mem_handle.get_table() or EMPTY_FRAGMENT
                fragment_shader_data.texture   = TPIX
                fragment_shader_data.tex       = tex
                fragment_shader_data.color     = C
                fragment_shader_data.x         = x
                fragment_shader_data.y         = y
                fragment_shader_data.z_correct = z
                fragment_shader_data.v1        = stv1
                fragment_shader_data.v2        = stv2
                fragment_shader_data.v3        = stv3

                local frag_data
                if make_fragment then frag_data = mem_handle.get_table() end
                for i=1,num do
                    local nm = naming[i]
                    frag_data[nm] = ((1 - t3) * temp_interpolants1[nm] + t3 * temp_interpolants2[nm])*z
                end
                fragment_shader_data.data = frag_data

                if tex then
                    local thisu,thisv = int_uv(bary_a,bary_b,bary_c,v0u,v0v,v1u,v1v,v2u,v2v)
                    fragment_shader_data.tx,fragment_shader_data.ty = thisu,thisv

                    local bary_aright,bary_bright,bary_cright = barycentric_coordinates(x+1  ,y,v0x,v0y,v1x,v1y,v2x,v2y)
                    local bary_adown,bary_bdown,bary_cdown    = barycentric_coordinates(x,y+1,v0x,v0y,v1x,v1y,v2x,v2y)

                    local uright,vright = int_uv(bary_aright,bary_bright,bary_cright,v0u,v0v,v1u,v1v,v2u,v2v)
                    local udown ,vdown  = int_uv(bary_adown,bary_bdown,bary_cdown,v0u,v0v,v1u,v1v,v2u,v2v)

                    local L = MAX(
                        ABS(thisu-uright)*tex.w,ABS(thisv-vright)*tex.h,
                        ABS(thisv-vdown) *tex.h,ABS(thisu-udown) *tex.w
                    )

                    fragment_shader_data.mipmap_level = L
                else
                    fragment_shader_data.mipmap_level = nil
                    fragment_shader_data.tx,fragment_shader_data.ty = nil,nil
                end
    
                fragment(x,y,(1 - t3) * z1 + t3 * z2,
                    fs(fragment_shader_data)
                )
            end
        end
    end
    return {triangle=function(fs,object,p1,p2,p3,tex,pixel_size,frag,stv1,stv2,stv3)
        local w,h   = graphics_bus.w/pixel_size,graphics_bus.h/pixel_size
        local origp1,origp2,origp3 = p1,p2,p3
        if p2[2] < p1[2] then p1,p2 = p2,p1 end
        if p3[2] < p2[2] then p2,p3 = p3,p2 end
        if p2[2] < p1[2] then p1,p2 = p2,p1 end
        if p1[2] == p2[2] then
            if p2[1] < p1[1] then p1,p2 = p2,p1 end
            draw_flat_top_triangle(fs,object,p1,p2,p3,tex,origp1,origp2,origp3,frag,w,h,stv1,stv2,stv3)
        elseif p2[2] == p3[2] then
            if p3[1] < p2[1] then p2,p3 = p3,p2 end
            draw_flat_bottom_triangle(fs,object,p1,p2,p3,tex,origp1,origp2,origp3,frag,w,h,stv1,stv2,stv3)
        else
            local alpha_split = (p2[2]-p1[2]) / (p3[2]-p1[2])
            local split_vertex = interpolate_vertex(p1,p3,alpha_split)
            
            if p2[1] < split_vertex[1] then
                draw_flat_bottom_triangle(fs,object,p1,p2,split_vertex,tex,origp1,origp2,origp3,frag,w,h,stv1,stv2,stv3)
                draw_flat_top_triangle   (fs,object,p2,split_vertex,p3,tex,origp1,origp2,origp3,frag,w,h,stv1,stv2,stv3)
            else
                draw_flat_bottom_triangle(fs,object,p1,split_vertex,p2,tex,origp1,origp2,origp3,frag,w,h,stv1,stv2,stv3)
                draw_flat_top_triangle   (fs,object,split_vertex,p2,p3,tex,origp1,origp2,origp3,frag,w,h,stv1,stv2,stv3)
            end
        end
    end}
end}