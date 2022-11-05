local interpolate_vertex = require("core.3D.geometry.interpolate_vertex")

return function(object,n,tris,v1,v2,v3,fs,index,triangle_texture)
    local alpha1 = (-v1[3]) / (v3[3]-v1[3])
    local alpha2 = (-v2[3]) / (v3[3]-v2[3])

    local v10 = interpolate_vertex(v1,v3,alpha1)
    local v01 = interpolate_vertex(v2,v3,alpha2)

    tris[n] = {v3,v01,v10,split=true,fs=fs,object=object,index=index,texture=triangle_texture}
end