function graph_12_8_edges()
  result::Array{Tuple{Int, Int}} = [(i, i + 1) for i in 1:19]
  append!(result, [
    (1,12),
    (1,14),
    (3,15),
    (4,16),
    (6,17),
    (7,18),
    (9,19),
    (10,20),
    (13,20),
    (14,18)
  ])
  return result
end