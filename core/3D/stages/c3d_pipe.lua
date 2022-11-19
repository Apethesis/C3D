local fragment_shader = require("core.3D.stages.fragment_shader")
local frustum_clip    = require("core.3D.geometry.clip_cull_frustum")

local matmul = require("core.3D.math.matmul")

local mem_handle = require("core.mem_manager")

local empty = {}

local VERT_1,VERT_2,VERT_3 = {},{},{}

return function(object,prev,geo,prop,efx,out,BUS,object_texture,camera)
    local frustum_handle = frustum_clip.init(BUS)
    local mem_manager = mem_handle.get(BUS)

    local per = BUS.perspective.matrix

    local scale = prop.scale_mat
    local rot   = prop.rotation_mat
    local pos   = prop.pos_mat

    local triangle_lookup = geo.triangle_lookup

    local vertex_shader = efx.vs
    local frag_shader   = efx.fs

    local vertice_index = 0

    local cam_transform = camera.transform
    local cam_position  = camera.position
    local cam_rotation  = camera.rotation

    local triangle_fragments = {}

    local curent_triangle   = out.n
    local output_triangles  = out.tris

    local normals           = geo.normals
    local normal_indices    = geo.normal_idx
    local triangle_textures = geo.texture_idx
    local pixel_sizes       = geo.pixel_sizes
    local uvs = geo.uvs
    local uv_indices = geo.uv_idx
    local nuvs  = next(uvs or empty) and next(uv_indices or empty)
    local nnorm = next(normals or empty) and next(normal_indices or empty)
    local ntexs = next(triangle_textures or empty)
    local npxsz = next(pixel_sizes or empty)
    local pixel_size = object.pixel_size
    local texture = object.texture
    local z_layer = object.z_layer

    local triangle_frag = fragment_shader(frag_shader)

    for i=1,#prev,3 do
        vertice_index = vertice_index + 1

        local fvert1,fvert2,fvert3,fvert4,fragment,data
        if vertex_shader then
            fvert1,fvert2,fvert3,fvert4,fragment,data = vertex_shader(prev[i],prev[i+1],prev[i+2],1,prop,scale,rot,pos,per,cam_transform,cam_position,cam_rotation)
        else
            local sc1,sc2,sc3,sc4 = matmul(prev[i],prev[i+1],prev[i+2],1,scale)
            local rx1,ry2,ry3,ry4 = matmul(sc1,sc2,sc3,sc4,rot)
            local tl1,tl2,tl3,tl4 = matmul(rx1,ry2,ry3,ry4,pos)
            local ct1,ct2,ct3,ct4
            if cam_transform then
                ct1,ct2,ct3,ct4 = matmul(tl1,tl2,tl3,tl4,cam_transform)
            else
                local cp1,cp2,cp3,cp4 = matmul(tl1,tl2,tl3,tl4,cam_position)
                ct1,ct2,ct3,ct4 = matmul(cp1,cp2,cp3,cp4,cam_rotation)
            end

            fvert1,fvert2,fvert3,fvert4 = matmul(ct1,ct2,ct3,ct4,per)
        end

        local belonging_triangles = triangle_lookup[vertice_index]
        for x=1,belonging_triangles.lenght do
            local triangle = belonging_triangles[x]
            local tindex   = triangle.index

            local t = triangle_fragments[tindex]
            if not t then
                t = mem_manager.get_table()
                t.added = 0
                triangle_fragments[tindex] = t
            end
            local added = t.added + 1
            t.added = added

            local part_mul = triangle.part*6
            t[part_mul-5] = fvert1
            t[part_mul-4] = fvert2
            t[part_mul-3] = fvert3
            t[part_mul-2] = fvert4
            t[part_mul-1] = data
            t[part_mul]   = fragment

            if added == 3 then
                VERT_1[1],VERT_1[2],VERT_1[3],VERT_1[4],VERT_1.val,VERT_1.frag = t[1], t[2], t[3], t[4], t[5], t[6]
                VERT_2[1],VERT_2[2],VERT_2[3],VERT_2[4],VERT_2.val,VERT_2.frag = t[7], t[8], t[9], t[10],t[11],t[12]
                VERT_3[1],VERT_3[2],VERT_3[3],VERT_3[4],VERT_3.val,VERT_3.frag = t[13],t[14],t[15],t[16],t[17],t[18]

                local triangle_id = tindex * 3

                if nuvs then
                    local uva = uv_indices[triangle_id-2]*2
                    local uvb = uv_indices[triangle_id-1]*2
                    local uvc = uv_indices[triangle_id]  *2
                    VERT_1[5],VERT_1[6] = uvs[uva-1],uvs[uva]
                    VERT_2[5],VERT_2[6] = uvs[uvb-1],uvs[uvb]
                    VERT_3[5],VERT_3[6] = uvs[uvc-1],uvs[uvc]
                else
                    VERT_1[5],VERT_1[6] = nil,nil
                    VERT_2[5],VERT_2[6] = nil,nil
                    VERT_3[5],VERT_3[6] = nil,nil
                end
                if nnorm then
                    local norma = normal_indices[triangle_id]  *3
                    local normb = normal_indices[triangle_id-1]*3
                    local normc = normal_indices[triangle_id-2]*3
        
                    local normal_1 = mem_manager.get_table()
                    local normal_2 = mem_manager.get_table()
                    local normal_3 = mem_manager.get_table()
        
                    normal_1[1],normal_1[2],normal_1[3] = normals[norma-2],normals[norma-1],normals[norma]
                    normal_2[1],normal_2[2],normal_2[3] = normals[normb-2],normals[normb-1],normals[normb]
                    normal_3[1],normal_3[2],normal_3[3] = normals[normc-2],normals[normc-1],normals[normc]
        
                    VERT_1.norm = normal_1
                    VERT_2.norm = normal_2
                    VERT_3.norm = normal_3
                else
                    VERT_1.norm = nil
                    VERT_2.norm = nil
                    VERT_3.norm = nil
                end

                triangle_fragments[tindex] = nil

                local tex = texture
                local pix_size = pixel_size
                if ntexs then tex = triangle_textures[tindex] end
                if npxsz then pix_size = pixel_sizes[tindex] end

                curent_triangle = frustum_handle(object,output_triangles,
                    VERT_1,VERT_2,VERT_3,
                    curent_triangle,triangle_frag,tindex,tex,pix_size,z_layer
                )
            end
        end
    end

    out.n = curent_triangle

    return output_triangles
end