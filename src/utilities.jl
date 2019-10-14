function calendar(v)
    lista = sort(union(v))
    dic = Dict(d => n for (n,d) in enumerate(lista))
    return [get(dic,x,0) for x in v]
end
