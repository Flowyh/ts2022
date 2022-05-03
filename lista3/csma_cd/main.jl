include("./simulation.jl")
import .CSMA_CD_Simulation
const Sim = CSMA_CD_Simulation

# Explanation: https://stackoverflow.com/a/38987059/18870209
macro Name(arg)
  string(arg)
end

function main(args::Array{String})
  mode = false
  if (length(args) == 1 && args[1] == "slow")
    mode = true
  end
  test = Sim.Simulation(cable_size=10)
  Sim.add_node!(test, Sim.new_node("A", 1, 0, 3))
  Sim.add_node!(test, Sim.new_node("B", 3, 5, 2))
  Sim.add_node!(test, Sim.new_node("C", 10, 10, 1))
  Sim.add_node!(test, Sim.new_node("D", 7, 0, 3))
  Sim.add_node!(test, Sim.new_node("E", 8, 0, 0))
  Sim.run(test, slow=mode)
  Sim.statistics(test)
  out = open("$(@Name test)_out.log", "w")
  for msg in Sim.messages
    write(out, msg)
  end
end

if abspath(PROGRAM_FILE) == @__FILE__
  main(ARGS)
end