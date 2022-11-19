return function(mesh)
    local vertex_triangles = {}
    for triangle_index,vertex_index in pairs(mesh.geometry.tris) do
        if not vertex_triangles[vertex_index] then
            vertex_triangles[vertex_index] = {lenght=0}
        end

        vertex_triangles[vertex_index].lenght = vertex_triangles[vertex_index].lenght + 1
        vertex_triangles[vertex_index][vertex_triangles[vertex_index].lenght] = {
            index=math.ceil(triangle_index/3),
            part =(triangle_index-1)%3+1
        }
    end
    mesh.geometry.triangle_lookup = vertex_triangles
    return mesh
end