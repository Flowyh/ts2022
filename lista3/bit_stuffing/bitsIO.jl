module BitsIO
  export bits_to_int, bits_to_bytes
  export bytes_to_int, bytes_to_str
  export int_to_bits, uint_to_bits
  export read_one_byte, read_n_bytes
  export write_byte, write_bytes, write_int, write_str
  export output_bit!

  const UINTS = Union{UInt128, UInt64, UInt32, UInt16, UInt8}
  const INTS = Union{Int128, Int64, Int32, Int16, Int8}
  
  function uint_to_bits(num::UINTS, padding::Int=0)::BitVector
    return BitVector(digits(num, base=2, pad=padding) |> reverse)
  end

  function int_to_bits(num::INTS, padding::Int=0)::BitVector
    return BitVector(digits(num, base=2, pad=padding) |> reverse)
  end

  function bits_to_int(bits::BitVector, sum::Int=0)::Int
    pow_two = 1
    for bit in view(bits, length(bits):-1:1)
      sum += pow_two * bit
      pow_two <<= 1
    end 
    return sum
  end

  function bits_to_bytes(bits::BitVector)::Vector{UInt8}
    if (length(bits) % 8 != 0) throw("Number of bits not a power of 8") end
    result = Vector{UInt8}(undef, 0)
    bytes_count::Int = fld(length(bits), 8)
    for i in 0:bytes_count-1
      push!(result, UInt8(bits_to_int(bits[8i+1:8(i+1)])))
    end
    return result
  end

  function bytes_to_int(bytes::Vector{UInt8})::Int
    result::Int = 0
    for i in 1:length(bytes)
      result += bytes[i] * (2^(8(i-1))) 
    end
    return result
  end

  function bytes_to_str(bytes::Vector{UInt8})::String
    result = ""
    for byte in bytes
      result *= Char(byte)
    end
    return result
  end

  function read_one_byte(file::IO)::UInt8
    return read(file, UInt8)
  end

  function read_n_bytes(file::IO, n::Int)::Vector{UInt8}
    bytes = Array{UInt8}(undef, 0)
    readbytes!(file, bytes, n)
    return bytes
  end

  function write_byte(byte::UInt8, out::IO)
    write(out, byte)
  end

  function write_bytes(bytes::Vector{UInt8}, out::IO)
    for byte in bytes
      write_byte(byte, out)
    end
  end

  function write_int(num::Int, out::IO)
    write(out, num)
  end

  function write_str(str::String, out::IO)
    write(out, str)
  end

  function output_bit!(bit, bit_buffer::BitVector, out::IO)
    push!(bit_buffer, bit)
    output_byte!(bit_buffer, out)
  end

  function output_byte!(bit_buffer::BitVector, out::IO)
    while (length(bit_buffer) >= 8)
      out_char = UInt8(bitarr_to_int(bit_buffer[1:8]))
      write(out, out_char)
      deleteat!(bit_buffer, 1:8)
    end
  end
end