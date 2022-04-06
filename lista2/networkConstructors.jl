  function asymmetricSameResistances12_8Network(t_limit::UInt, min_res::Float64, pckts::UInt, bndwdth::UInt, pckt_size::UInt)
    return Network(graphEightTwelve, asymmetricTrafficMatrix, t_limit, minimalResistances, min_res, pckts, bndwdth, pckt_size)
  end

  function asymmetricRandResistances12_8Network(t_limit::UInt, min_res::Float64, pckts::UInt, bndwdth::UInt, pckt_size::UInt)
    return Network(graphEightTwelve, asymmetricTrafficMatrix, t_limit, randomResistances, min_res, pckts, bndwdth, pckt_size)
  end

  function symmetricSameResistances12_8Network(t_limit::UInt, min_res::Float64, pckts::UInt, bndwdth::UInt, pckt_size::UInt)
    return Network(graphEightTwelve, symmetricTrafficMatrix, t_limit, minimalResistances, min_res, pckts, bndwdth, pckt_size)
  end

  function symmetricRandResistances12_8Network(t_limit::UInt, min_res::Float64, pckts::UInt, bndwdth::UInt, pckt_size::UInt)
    return Network(graphEightTwelve, symmetricTrafficMatrix, t_limit, randomResistances, min_res, pckts, bndwdth, pckt_size)
  end