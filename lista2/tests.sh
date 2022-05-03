julia --threads 4 main.jl 0.005 0.90 1 10 0.1
julia --threads 4 main.jl 0.005 0.95 1 10 0.1
julia --threads 4 main.jl 0.005 0.99 1 10 0.1

julia --threads 4 main.jl 0.005 0.90 2 10 0.1
julia --threads 4 main.jl 0.005 0.95 2 10 0.1
julia --threads 4 main.jl 0.005 0.99 2 10 0.1

julia-1.7.2 --threads 4 main.jl 0.005 0.90 4 10 0.1
julia-1.7.2 --threads 4 main.jl 0.005 0.95 4 10 0.1
julia-1.7.2 --threads 4 main.jl 0.005 0.99 4 10 0.1

julia-1.7.2 --threads 4 main.jl 0.005 0.90 8 10 0.1
julia-1.7.2 --threads 4 main.jl 0.005 0.95 8 10 0.1
julia-1.7.2 --threads 4 main.jl 0.005 0.99 8 10 0.1