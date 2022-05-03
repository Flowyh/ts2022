import Base.@kwdef

@kwdef mutable struct Node
  name::String = ""
  position::Int = -1
  id::Int = position
  idle::Bool = true
  idle_time::Int = -1
  collision::Bool = false
  detected_collisions::Int = 0
  frames::Int = -1
end

using Random

function node_collision_idle_time!(node::Node)
  node.detected_collisions += 1
  wait_time_range::Int = 2^node.detected_collisions
  node.idle_time = rand(0:min(wait_time_range, 2^10))
end

@enum packet_directions begin
  left
  right
  both
end

@kwdef mutable struct NodePacket
  node::Node = nothing
  collision_packet::Bool = node.collision
  direction::packet_directions
end
