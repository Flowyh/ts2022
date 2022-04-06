function graph_10_10_edges()
  result::Array{Tuple{Int, Int}} = [(i, i + 1) for i in 1:19]
  append!(result, [(i, i + 11) for i in 1:8])
  append!(result, 
  [
    (10, 1),
    (11, 20)
  ])
  return result
end