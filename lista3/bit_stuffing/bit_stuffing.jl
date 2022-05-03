include("./bitsIO.jl")
using .BitsIO

const FRAME_EDGE = "01111110"
const FRAME_SIZE = 32
const MODES = ["enc", "dec"]

function bits_to_str(bits::BitVector)
  result = ""
  for bit in bits
    if (bit) result *= "1"
    else result *= "0" end
  end
  return result
end

function crc32_to_bits(str::String)::BitVector
  crc::UInt32 = Base._crc32c(str)
  return uint_to_bits(crc, 32)
end

function encode_str(input::IO, output::IO)
  bytes = Vector{UInt8}(undef, 0)
  bits = BitVector(undef, 0)
  while !(eof(input))
    bytes = read_n_bytes(input, fld(FRAME_SIZE, 8))
    for byte in bytes
      push!(bits, uint_to_bits(byte, 8)...)
    end
    crc_bits = crc32_to_bits(bytes_to_str(bytes)) # CRC
    for crc_bit in crc_bits 
      push!(bits, crc_bit)
    end
    bits_str = bits_to_str(bits)
    stuffed_str::String = replace(bits_str, r"11111" => s"111110") # Add guarding zeros
    write_str(FRAME_EDGE * stuffed_str * FRAME_EDGE * "\n", output) # Save frame to file
    empty!(bits)
  end
end

function decode_str(input::IO, output::IO)
  input_str::String = read(input, String)
  input_str = replace(input_str, r"01111110" => s"|") # Replace frames with |
  input_str = replace(input_str, r"111110" => s"11111") # Remove guarding zerose
  frames = split(input_str, "|")
  bits = BitVector(undef, 0)
  for frame in frames
    frame = strip(frame)
    if (isempty(frame)) continue end
    for bit in frame
      push!(bits, parse(Int, bit))
    end
    data = bits[1:end-FRAME_SIZE]
    crc = bits[end-FRAME_SIZE+1:end]
    try
      data_bytes = bits_to_bytes(data)
      if (crc != crc32_to_bits(bytes_to_str(data_bytes))) 
        throw("CRC32 check failed")
      else
        for byte in data_bytes
          write_byte(byte, output)
        end
      end
    catch e 
      println("Error: $e. Frame malformed, omitting.")
    end
    empty!(bits)
  end
end

function usage()
  println("Usage: julia bit_stuffing.jl [input_path] [output_path] [enc/dec/chk]")
end

function main(args::Array{String})
  if (length(args) < 3)
    println("Please provide at least 3 arguments")
    usage()
    exit(1)
  end
  input = args[1]
  output = args[2]
  mode = args[3]
  if !(isfile(input)) println("Invalid input path provided"); usage(); exit(1) end
  input_file = open(input, "r")

  if (mode == "enc")
    output_file = open(output, "w")
    @time encode_str(input_file, output_file)
  elseif (mode == "dec")
    output_file = open(output, "w")
    @time decode_str(input_file, output_file)
  elseif (mode == "chk")
    plain_sum = Base._crc32c(input_file)
    println("Before encoding chekcsum (crc32c): $(plain_sum)")
    decoded_sum = Base._crc32c(read(open(output, "r")))
    println("After decoding chekcsum (crc32c): $(decoded_sum)")
    println("Are files the same? $(plain_sum == decoded_sum)")
  else
    println("Invalid mode provided"); usage(); exit(1)
  end

end

if abspath(PROGRAM_FILE) == @__FILE__
  main(ARGS)
end