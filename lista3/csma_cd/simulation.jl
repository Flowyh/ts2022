module CSMA_CD_Simulation
  include("./node.jl")
  
  export new_node, add_node!, messages
  export Simulation, run, statistics

  const messages = Vector{String}(undef, 0)
  const wait_for_enter() = (print(stdout, "\nPress Enter key to continue"); read(stdin, 1); nothing)
  const announce(msg::String) = (println(msg); push!(messages, msg * "\n"); nothing)
  
  @kwdef mutable struct Simulation
    cable_size::Int = 0
    cable::Vector{Vector{NodePacket}} = empty_cable(cable_size)
    available_positions::Dict{Int, Node} = Dict(i => Node() for i in 1:cable_size)
    broadcasting_nodes::Vector{Node} = []
    nodes_statistics::Dict{String, Dict{Symbol, Int}} = Dict()
  end

  function new_node(
    _name::String,
    _position::Int,
    _idle_time::Int,
    _frames::Int
  )::Node
    return Node(
      name=_name, 
      position=_position, 
      idle_time=_idle_time, 
      frames=_frames
    )
  end

  function add_node!(sim::Simulation, node::Node)
    # Error check
    !(node.position in keys(sim.available_positions)) &&  throw("Invalid node position provided")
    !(sim.available_positions[node.position].id == -1) && throw("Node's position is already taken")
    # Add to available position
    sim.available_positions[node.position] = node
    # If has to broadcast, add to broadcasting list
    (node.frames > 0) && push!(sim.broadcasting_nodes, node)
    # Add new statistics
    sim.nodes_statistics[node.name] = Dict(
      :collisions => 0, 
      :idle_time => 0, 
      :stop_iteration => 0
    )
  end

  function is_cable_empty(cable::Vector{Vector{NodePacket}})
    for fragment in cable
      if !(isempty(fragment)) return false end  
    end
    return true
  end

  function empty_cable(size::Int)::Vector{Vector{NodePacket}}
    return [[] for _ in 1:size]
  end

  function cable_state_str(sim::Simulation)::String
    str::String = ""
    str *= "|"
    for fragment in sim.cable
      str *= "["
      for packet_pos in 1:length(fragment)-1
        str *= "$(fragment[packet_pos].node.name)$(fragment[packet_pos].collision_packet == true ? "!" : ""),"
      end
      if (length(fragment) > 0) str *= "$(fragment[end].node.name)" 
      else str *= " " end
      str *= "]"
    end
    str *= "|"

    return str
  end

  function run(sim::Simulation; slow::Bool)
    iteration = 0
    while (!isempty(sim.broadcasting_nodes) || !is_cable_empty(sim.cable))
      iteration += 1
      announce("\nIteration: $iteration")
      step(sim, iteration)
      announce("Cable after $iteration:\n$(cable_state_str(sim))")
      if (slow) wait_for_enter() end
    end
  end

  function step(sim::Simulation, iteration::Int)
    next_state::Vector{Vector{NodePacket}} = empty_cable(sim.cable_size)
    propagate_packets!(sim, next_state)
    broadcasts!(sim, next_state, iteration)
    sim.cable = next_state
  end

  function propagate_packets!(sim::Simulation, next_state::Vector{Vector{NodePacket}})
    # Propagate
    for (pos, cable_fragment) in enumerate(sim.cable)
      for packet in cable_fragment
        # Propagate left
        if (packet.direction == left && pos > 1)
          push!(next_state[pos - 1], packet)
        # Propagate Right
        elseif (packet.direction == right && pos < sim.cable_size)
          push!(next_state[pos + 1], packet)
        # Propagate both (append packet directed to the left, and directed to the right)
        elseif (packet.direction == both)
          if (pos > 1) push!(next_state[pos - 1], NodePacket(node=packet.node, direction=left)) end
          if (pos < sim.cable_size) push!(next_state[pos + 1], NodePacket(node=packet.node, direction=right)) end
        end
      end
    end
  end

  function broadcasts!(sim::Simulation, next_state::Vector{Vector{NodePacket}}, iteration::Int)
    for _node in sim.broadcasting_nodes
      if (_node.idle) # Start broadcasting_nodes
        if (_node.idle_time > 0) # If has to wait, wait
          announce("$(_node.name) is waiting")
          _node.idle_time -= 1
        else # If doesn't have to wait
          if (length(next_state[_node.position]) == 0) # If possible to broadcast
            announce("$(_node.name) started broadcasting")
            _node.idle = false
            _node.idle_time = 2sim.cable_size
          else # If not, wait for next iteration, add to statistic
            announce("$(_node.name) is waiting")
            sim.nodes_statistics[_node.name][:idle_time] += 1
          end
        end
      elseif (!_node.idle && _node.idle_time == 0) # End broadcasting
        announce("$(_node.name) stopped broadcasting")
        _node.idle = true
        if (_node.collision) # Reset collision if one has occured
          _node.collision = false
          node_collision_idle_time!(_node)
          sim.nodes_statistics[_node.name][:idle_time] += _node.idle_time # Add new idle_time to statistics
        else
          _node.frames -= 1 # Decrement number of left frames
          sim.nodes_statistics[_node.name][:collisions] += _node.detected_collisions # Add acknowledged detections to statistic
          _node.detected_collisions = 0
          if (_node.frames == 0) # Remove from active nodes if all packets were sent
            announce("$(_node.name) went silent")
            # Add to statitics
            filter!(x -> x != _node, sim.broadcasting_nodes)
            sim.nodes_statistics[_node.name][:stop_iteration] = iteration
          end
        end

        announce("$(_node.name) idle time: $(_node.idle_time) iteration/s")
      elseif (!_node.idle && _node.idle_time > 0) # Continue broadcasting
        if (!_node.collision && !isempty(next_state[_node.position])) # Collision detected, send collision signal, reset idle_time
          announce("$(_node.name) detected a collision, sending collision signal")
          _node.collision = true
          _node.idle_time = 2sim.cable_size
        end
        announce("$(_node.name) continues broadcasting")
        push!(next_state[_node.position], NodePacket(node=_node, direction=both)) # Add new packet signal
        _node.idle_time -= 1
      end
    end
  end

  function statistics(sim::Simulation)
    announce("\nStatistics:\n")
    for node_name in sort(collect(keys(sim.nodes_statistics)))
      announce("Node: $node_name")
      for statistic in keys(sim.nodes_statistics[node_name])
        announce("$statistic: $(sim.nodes_statistics[node_name][statistic])")
      end
      announce("\n")
    end
  end
end