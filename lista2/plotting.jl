using Plots
using ColorSchemes
import JSON

ENV["GKSwstype"] = "100"

test_titles = Dict(
  "bandwidthTest" => "Bandwidth test network reliabilities",
  "newEdgeTest" => "New edge test network reliabilities",
  "trafficTest" => "Traffic test network reliabilities"
)

test_names = Dict(
  "bandwidthTest" => "% increase in network bandwidth",
  "newEdgeTest" => "Number of added edges",
  "trafficTest" => "% increase in network traffic"
)

function plot_data(x, y, z, scale, xl::String, yl::String, t::String, w=900, h=600)
  x *= scale
  x = round.(x, digits = 1)
  plt = heatmap(x, y, z, 
    xticks = 0:0.1scale:1scale,
    xlabel = xl,
    ylabel = yl,
    zlabel = "Network reliability in %",
    yformatter = :plain,
    title = t,
    margin = 10Plots.mm,
    c = cgrad(:turku)
    )
  plot!(plt, size=(w, h))
  return plt
end

function main(args::Array{String})
  !isdir("./jsons") && return
  isdir("./plots") || mkdir("./plots")
  data = Dict()
  foreach(readdir("./jsons")) do f
    data[f] = JSON.parsefile("./jsons/$f"; dicttype=Dict, inttype=Int, use_mmap=true)
    f_split = split(strip(f), "-")
    rel = Array{Float64}(undef, 10, 11)
    for i in 1:10
      for j in 1:11
        rel[i, j] = data[f]["rel_avgs"][11(i-1) + j]
      end
    end
    data[f]["rel_avgs"] = rel
    data[f]["title"] = f_split[1]
    data[f]["p"] = parse(Float64, f_split[3][2:end])
    data[f]["t_max"] = round.(data[f]["t_max"], digits=5)
    data[f]["m"] = parse(Int, f_split[4][2:end])
    data[f]["k"] = parse(Int, f_split[6][2:end])
    data[f]["scale"] = 1.0
    if (occursin(r"^newEdgeTest", f_split[1])) data[f]["scale"] = 10.0 end
  end
  for key in keys(data)
    plt = plot_data(
      data[key]["increment"], 
      data[key]["t_max"], 
      data[key]["rel_avgs"], 
      data[key]["scale"],
      "$(test_names[data[key]["title"]])",
      "T_max",
      "$(test_titles[data[key]["title"]]) for p=$(data[key]["p"]), packet_size=$(data[key]["m"]), retries=$(data[key]["k"])"
      )
    println(plt)
    savefig(plt, "./plots/$key.png")
  end
end

if abspath(PROGRAM_FILE) == @__FILE__
  main(ARGS)
end