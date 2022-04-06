module NetworkGraphs
  export plotDoubleCyclicGraph
  export Network, networkReliability, averagePacketDelay
  export asymmetricSameResistances12_8Network
  export asymmetricRandResistances12_8Network
  export symmetricSameResistances12_8Network
  export symmetricRandResistances12_8Network
  export randomIntPair, addPackets, addBandwidth, addEdge, replaceTraffic!

  # Graphs
  using Graphs
  include("./topologies/topologies.jl")
  using .GraphTopologies

  # Plotting
  import Cairo, Fontconfig
  using GraphPlot

  mutable struct Network
    graph::SimpleGraph
    edges::Array{Edge}
    available_edges::Array{Edge}
    vertices::Array{UInt}
    traffic::Array{UInt, 2}
    damage_resistance::Array{Float64}
    flow::Array{UInt}
    bandwidth::Array{UInt}
    packet_size::UInt
    # Copy params
    functions::Dict
    params::Dict

    function Network(
      topology::Function, traffic_type::Function, 
      traffic_limit::UInt, resistance_type::Function, 
      min_resistance::Float64, packets_per_mbs::UInt, 
      bandwidth_scale::UInt, packet_size::UInt
    )
      println("Creating new network . . .")
      this = new()
      this.functions = Dict(
        :topology => topology,
        :traffic_type => traffic_type,
        :resistance_type => resistance_type
      )
      this.params = Dict(
        :traffic_limit => traffic_limit,
        :min_resistance => min_resistance,
        :packets_per_mbs => packets_per_mbs,
        :bandwidth_scale => bandwidth_scale,
      )
      println("Creating network's graph . . .")
      this.graph = topology()
      this.edges = collect(edges(this.graph))
      println("Finding free edges . . .")
      this.available_edges = buildAvailableEdges(this.graph)
      this.vertices = collect(vertices(this.graph))
      println("Randomizing traffic matrix . . .")
      this.traffic = traffic_type(length(this.vertices), traffic_limit)
      println("Setting resistances . . .")
      this.damage_resistance = resistance_type(ne(this.graph), min_resistance)
      println("Computing packet flow values on edges . . .")
      this.flow = packetFlow(this.graph, this.traffic)
      println("Assigning bandwidth to edges . . .")
      this.bandwidth = bandwidths(this.flow, packets_per_mbs, bandwidth_scale)
      this.packet_size = packet_size
      println("Done!")
      return this
    end

    function Network(
      graph::SimpleGraph, bandwidths::Array{UInt}, parentNetwork::Network
    )
      this = new()
      this.functions = copy(parentNetwork.functions)
      this.params = copy(parentNetwork.params)
      this.graph = graph
      this.edges = collect(edges(this.graph))
      this.available_edges = buildAvailableEdges(graph)
      this.vertices = collect(vertices(graph))
      this.traffic = copy(parentNetwork.traffic)
      this.damage_resistance = copy(parentNetwork.damage_resistance)
      this.flow = packetFlow(graph, this.traffic)
      this.bandwidth = bandwidths
      this.packet_size = copy(parentNetwork.packet_size)

      return this
    end

    function Network(parentNetwork::Network)
      this = new()
      this.functions = copy(parentNetwork.functions)
      this.params = copy(parentNetwork.params)
      this.graph = copy(parentNetwork.graph)
      this.edges = copy(parentNetwork.edges)
      this.available_edges = copy(parentNetwork.available_edges)
      this.vertices = copy(parentNetwork.vertices)
      this.traffic = copy(parentNetwork.traffic)
      this.damage_resistance = copy(parentNetwork.damage_resistance)
      this.flow = copy(parentNetwork.flow)
      this.bandwidth = copy(parentNetwork.bandwidth)
      this.packet_size = copy(parentNetwork.packet_size)
      return this
    end
  end

  function replaceTraffic!(net::Network, traffic::Array{UInt, 2})
    for i in 1:size(net.traffic, 1)
      for j in 1:size(net.traffic, 1)
        net.traffic[i, j] = traffic[i, j]
      end
    end
    net.flow = packetFlow(net.graph, traffic)
    net.bandwidth = bandwidths(net.flow, net.params[:packets_per_mbs], net.params[:bandwidth_scale])
  end

  function plotDoubleCyclicGraph(net::Network, outer_cycle::Int)
    # Node labels
    nodelabel = [i for i in 1:nv(net.graph)]
    # Edge labels
    edgelabel = ["a$(net.flow[i])\nc$(net.bandwidth[i])" for i in 1:length(net.edges)]
    # Color cycles
    colors = [1 for i in 1:outer_cycle]
    append!(colors, [2 for i in outer_cycle+1:nv(net.graph)])
    nodecolor = ["royalblue3", "orange"]
    nodefillc = nodecolor[colors]
    #Plot
    # gplot(net.graph, edgelabel=edgelabel, edgelabelc="lime", edgelabelsize=0.01, nodelabel=nodelabel, nodefillc=nodefillc) # linetype="curve"
    gplot(net.graph, nodelabel=nodelabel, nodefillc=nodefillc) # linetype="curve"
  end

  function graphTenTen()
    edges::Array{Tuple{Int, Int}} = graph_10_10_edges()
    return buildGraph(20, edges)
  end

  function graphEightTwelve()
    edges::Array{Tuple{Int, Int}} = graph_12_8_edges()
    return buildGraph(20, edges)
  end
  
  function buildGraph(vertices::Int, edges::Array{Tuple{Int, Int}})
    graph::SimpleGraph = SimpleGraph(vertices, 0)
    for e in edges
      add_edge!(graph, e[1], e[2])
    end
    return graph
  end

  function buildAvailableEdges(graph::SimpleGraph)
    length::Int = nv(graph)
    available::Array{Edge} = []
    for i in 1:length
      for j in i+1:length
        push!(available, Edge(i, j))
      end
    end

    taken::Array{Edge} = []
    for edge in edges(graph)
      push!(taken, edge)
      push!(taken, Edge(dst(edge), src(edge))) # reverse
    end
    return filter!(x->!(x in taken), available)
  end

  using Random

  function random_batch(size::Int, limit::UInt)
    rng::AbstractRNG = MersenneTwister()
    batch::Array{UInt} = rand(rng, UInt, size)
    return convert(Array{UInt, 1}, map(x -> (x % (limit - 1) + 1), batch))
  end

  function symmetricTrafficMatrix(vertices::Int, limit::UInt)
    batch_size::Int = (vertices) * (vertices - 1) / 2
    batch::Array{UInt} = random_batch(batch_size, limit)
    batch_index::Int = 1

    result::Array{UInt} = zeros(UInt, vertices, vertices)

    for i in 1:vertices
      for j in i+1:vertices
        result[i, j] = result[j, i] = batch[batch_index]
        batch_index += 1
      end
    end
    return result
  end

  function asymmetricTrafficMatrix(vertices::Int, limit::UInt)
    batch_size::Int = vertices * (vertices - 1)
    batch::Array{UInt} = random_batch(batch_size, limit)
    batch_index::Int = 1

    result::Array{UInt} = zeros(UInt, vertices, vertices)
    batch_index = 1
    for i in 1:vertices
      for j in 1:vertices
        if (i == j) continue end
        result[i, j] = batch[batch_index]
        batch_index += 1
      end
    end
    return result
  end

  function sameEdge(edge1::Edge, edge2::Edge)
    return ((src(edge1) == src(edge2)) && (dst(edge1) == dst(edge2))) || ((src(edge1) == dst(edge2)) && (dst(edge1) == src(edge2)))
  end
  
  
  function packetFlow(graph::SimpleGraph, traffic::Array{UInt, 2})
    E = collect(edges(graph))
    vertices = nv(graph)
    result::Array{UInt} = zeros(ne(graph))
    for edge in 1:ne(graph)
      for i in 1:vertices
        for j in 1:vertices
          if (i == j) continue end
          path = a_star(graph, i, j)
          id = findfirst(x -> sameEdge(x, E[edge]), path)
          if (id === nothing) continue end
          result[edge] += traffic[i, j]
        end
      end
    end
    return result
  end
  
  function updatePacketFlow!(net::Network)
    net.flow = packetFlow(net.graph, net.traffic)
  end

  function bandwidths(flow::Array{UInt}, packets_per_mbs::UInt, scale::UInt)
    return map(x -> UInt(ceil(scale * x / packets_per_mbs) * packets_per_mbs), flow)
  end

  function minimalResistances(edges::Int, min::Float64)
    result::Array{Float64} = [min for i in 1:edges]
    return result
  end

  function randomResistances(edges::Int, min::Float64)
    rng::AbstractRNG = MersenneTwister()
    result::Array{Float64} = [((1 - min) .* rand(rng, Float64, 1) .+ min)[1] for i in 1:edges]
    return result
  end

  function averagePacketDelay(network::Network)
    result::Float64 = 0
    for i in 1:ne(network.graph)
      flow_bits = network.flow[i] * network.packet_size
      result += flow_bits / (network.bandwidth[i] - flow_bits)
    end
    traffic_sum_inv::Float64 = 1 / sum(network.traffic)
    return traffic_sum_inv * result
  end
  
  function destroyEdge(resistance::Float64)
    rng::AbstractRNG = MersenneTwister()
    return resistance < rand(rng)
  end

  function networkReliability(net::Network, T_max::Float64, p::Float64, m::UInt, retries::UInt)
    net.params[:min_resistance] = p
    net.damage_resistance = minimalResistances(ne(net.graph), p)
    net.packet_size = m
    successes::UInt = 0x0
    for i in 1:retries
      # println("Try: $i / $retries, successes: $successes")
      mutatedNetwork = Network(net)
      removed = 0
      edges_count = ne(net.graph)
      for j in 1:edges_count
        if (destroyEdge(p))
          rem_edge!(mutatedNetwork.graph, collect(edges(mutatedNetwork.graph))[j - removed])
          deleteat!(mutatedNetwork.bandwidth, j - removed)
          removed += 1
        end
      end
      if (!is_connected(mutatedNetwork.graph)) continue end
      traffic_jam::Bool = false
      for j in 1:ne(mutatedNetwork.graph)
        if (mutatedNetwork.bandwidth[j] / mutatedNetwork.packet_size < mutatedNetwork.flow[j])
          traffic_jam = true
          break
        end
      end
      avg_delay = averagePacketDelay(mutatedNetwork)
      if (!traffic_jam && avg_delay < T_max) successes += 1 end
      traffic_jam = false
      mutatedNetwork = nothing
    end
    return successes / retries
  end

  function randomIntPair(min, max)
    first = randomIntExcluding(min, max, max + 1)
    second = randomIntExcluding(min, max, first)
    return (first, second)
  end

  function randomIntExcluding(min, max, excluded) 
    rng::AbstractRNG = MersenneTwister()
    n::Int = rand(rng, UInt) % (max - min) + min
    if (n >= excluded) n += 1 end
    return n
  end

  function addPackets(net::Network, increase::Float64)
    mutatedNetwork::Network = Network(net)
    len = size(mutatedNetwork.traffic, 1)
    for i in 1:len
      for j in 1:len
        mutatedNetwork.traffic[i, j] = trunc(UInt, mutatedNetwork.traffic[i, j] * (1.0 + increase))
      end
    end
    updatePacketFlow!(mutatedNetwork)
    return mutatedNetwork
  end

  function addBandwidth(net::Network, increase::Float64)
    mutatedNetwork::Network = Network(net)
    len = size(mutatedNetwork.bandwidth, 1)
    for i in 1:len
      mutatedNetwork.bandwidth[i] = trunc(UInt, mutatedNetwork.bandwidth[i] * (1.0 + increase))
    end
    return mutatedNetwork
  end

  function addEdge(net::Network)
    graph = copy(net.graph)
    idx = rand(1:length(net.available_edges))
    source = src(net.available_edges[idx])
    dest = dst(net.available_edges[idx])
    add_edge!(graph, source, dest)

    bandwidths::Array{UInt} = copy(net.bandwidth)
    push!(bandwidths, trunc(UInt, sum(bandwidths) / length(bandwidths)))
    mutatedNetwork = Network(graph, bandwidths, net)
    return mutatedNetwork
  end

  include("networkConstructors.jl")
end