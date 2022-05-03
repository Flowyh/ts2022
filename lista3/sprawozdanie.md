# Sprawozdanie [Lista nr 3](https://cs.pwr.edu.pl/bojko/2122_2lato/tss.html)

| Przedmiot  | Technologie sieciowe   |
| ---------- | ---------------------- |
| Prowadzący | Mgr inż. Dominik Bojko |
| Autor      | Maciej Bazela          |
| Indeks     | 261743                 |
| Grupa      | Czw. 15:15-16:55       |
| Kod grupy  | K03-76c                |

Kod źródłowy znajduje się w repozytorium na moim [githubie](https://github.com/Flowyh/ts2022).

#### 1. Wymagania

Celem tej listy było zaimplementowanie dwóch programów:

- pierwszy z nich dotyczył ramkowania z [rozpychaniem bitów](https://en.wikipedia.org/wiki/Bit_stuffing),
- drugi miał symulować ethernetową metodę dostępu do medium transmisyjnego [CSMA/CD](https://en.wikipedia.org/wiki/Carrier-sense_multiple_access_with_collision_detection).

#### 1.1 Środowisko

Do rozwiązania tych zadań wykorzystałem język [Julia](https://julialang.org/).

#### 2. Ramkowanie z rozpychaniem bitów

##### 2.1 Struktura ramki

Ramki tworzone zgodnie z zasadą rozpychania bitów mają określoną strukturę:

```
[flaga graniczna|nagłówek|dane|crc|flaga graniczna]
```

Flagom granicznym odpowiada ciąg bitów: 01111110

Danymi, które będziemy ramkować, będą sczytane z pliku bajty.

Dla przejrzystości zakodowanych plików wynikowych przyjąłem, że zawsze sczytujemy określoną ilość bitów z pliku, np. `FRAME_SIZE=32`.

##### 2.2 Rozpychanie bitów

"Rozpychanie" bitów polega na dodawaniu zerowego bitu po każdej pięcio-elementowej sekwencji jedynek.

Na przykład, sczytując z pliku ciąg "}}}}" i zamieniająć poszczególne litery na ich wartości w UTF8:

```
01111101 01111101 01111101 01111101
```

po "rozpychaniu" otrzymamy:

```md
011111001 011111001 011111001 011111001
```

##### 2.3 CRC

Liczenie pola kontrolnego CRC pozostawiłem osobom ode mnie mądrzejszym.

Bardzo wygodny ku temu okazał się fakt, że Julia ma wbudowaną funkcję do obliczania CRC32c:

```julia
julia> test = "}}}}"
"}}}}"

julia> Base._crc32c(test)
0x693bb197
```

Sczytane bity z pliku wejściowego zamieniałem na String, liczyłem ich pole kontrolne CRC i zamieniałem z powrotem na bity:

```julia
function crc32_to_bits(str::String)::BitVector
  crc::UInt32 = Base._crc32c(str)
  return uint_to_bits(crc, 32)
end
```

##### 2.4 Kodowanie ramek

Kodowanie ciągu znaków na ramki, polegało na:

- czytaniu `FRAME_SIZE / 8` bajtów z pliku,
- liczeniu CRC,
- "rozpychaniu" pięcio-elementowych sekwencji jedynek
- i opakowywaniu wszystkiego w ramki graniczne.

Schemat powtarzamy dopóki nie sczytaliśmy wszystkich bajtów z pliku.

Wynikowe ramki dla czytelności zamieniałem na String zer i jedynek i zapisywałem do pliku wyjściowego, podanego jako argument funkcji:

```julia
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
```

##### 2.5 Dekodowanie ramek

Wczytanie zakodowanego pliku, polegało na:

- wczytaniu całego pliku jako String,
- zamianie flag granicznych (ciągów "01111110") na znak nie będący ani zerem ani jedynką (np. "|"),
- usunięciu zer powstałych przez "rozpychanie" bitów,
- rozdzielenie Stringu na osobne ramki.

Dla każdej z ramek:

- zamieniamy ciąg znaków "0" i "1" z powrotem na bity,
- rozdzielamy dane od crc (wiemy, że crc ma 32 bity, dlatego możemy bez problemu od siebie je oddzielić),
- liczymy crc dla szczytanych bitów:
  - jeśli crc nie zgadza się ze sczytanym crc lub liczba bitów danych nie jest potęgą ósemki, odrzucamy ramkę,
  - w przeciwnym przypadku zapisujemy zdekodowane dane do pliku wyjściowego, podanego jako argument funkcji.

```julia
function decode_str(input::IO, output::IO)
  input_str::String = read(input, String)
  input_str = replace(input_str, r"01111110" => s"|") # Replace frames with |
  input_str = replace(input_str, r"111110" => s"11111") # Remove guarding zeroes
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
```

##### 2.6 Uruchomienie programu:

Program przyjmuje 3 argumenty:

- ścieżka pliku wejściowego
- ścieżka pliku wyjściowego
- tryb:
  - enc - kodowanie
  - dec - dekodowanie
  - chk - sprawdzenie czy dwa pliki są takie same

Przykład uruchomienia:

```sh
julia bit_stuffing.jl test out enc # kodowanie
julia bit_stuffing.jl out decoded dec # dekodowanie
julia bit_stuffing.jl test decoded chk # sprawdzenie
```

##### 2.7 Przykład działania:

##### 2.7.1 Poprawne ramki:

Plik testowy: test

```
$ cat test
Ala ma kota
Kot ma Alę
Zawsze się zastanawiałem jak to jest możliwe że kot ma Alę,
przecież to Ala jest jego właścicielką...

```

Kodowanie:

```
$ julia bit_stuffing.jl test out enc
  0.076200 seconds (316.24 k allocations: 18.363 MiB, 97.78% compilation time)
```

```
$ cat out
01111110010000010110110001100001001000000000110110101001011011000010010101111110
01111110011011010110000100100000011010110110000001100011110010101110111001111110
01111110011011110111010001100001000010101110101100100001111011001001001101111110
01111110010010110110111101110100001000001100110001001001111001000001101101111110
01111110011011010110000100100000010000010010101100111100011011000000100001111110
01111110011011001100010010011001000010100001010000010100001101000101011001111110
01111110010110100110000101110111011100110110011100011010101101101111001001111110
011111100111101001100101001000000111001110010100010111101111100001010001101111110
01111110011010011100010010011001001000000000001010001110110011101101111001111110
011111100111101001100001011100110111010000101010011111011101001110100111001111110
01111110011000010110111001100001011101110001000000001100100101001001101101111110
011111100110100101100001110001011000001000101100110001001110101111100010101111110
01111110011001010110110100100000011010101100001011000011101100001101010001111110
01111110011000010110101100100000011101001101010001110110000011110111100001111110
01111110011011110010000001101010011001010101010000011110011100011011110101111110
01111110011100110111010000100000011011011101011010011010101001100100000101111110
011111100110111110100010110111100011011001001100000101001001110110001011101111110
0111111001101001011101110110010100100000110000001001111101111100011010100001111110
01111110110001011011110001100101001000001100000001001010110100110000010101111110
01111110011010110110111101110100001000000001101101101100111100001001000001111110
01111110011011010110000100100000010000010010101100111100011011000000100001111110
01111110011011001100010010011001001011000001001000001000010111010110000001111110
011111100010000000001010011100000111001011000111100001101100001111101100101111110
01111110011110100110010101100011011010010010010000010010011110010110100101111110
011111100110010111000101101111000010000000101111100011011010100011010011101111110
01111110011101000110111100100000010000010000000010111001110111001011100101111110
01111110011011000110000100100000011010100100111101001101111000110101010101111110
011111100110010101110011011101000010000011111011101000000011001100101000101111110
011111100110101001100101011001110110111110010010101011101010011100110000001111110
011111100010000001110111110000101100000101011001010110011110000110011001101111110
011111100110000111000101100110110110001111001010101000111010001011011111001111110
0111111001101001011000110110100101100101100010011111001111000101111101110001111110
011111100110110001101011110001001000010110110101110011111000101011101011101111110
01111110001011100010111000101110000010100100010101010101010001001010111001111110
```

Dekodowanie:

```
$ julia bit_stuffing.jl out decoded dec
  0.000262 seconds (1.49 k allocations: 93.203 KiB)
```

```
$ cat decoded
Ala ma kota
Kot ma Alę
Zawsze się zastanawiałem jak to jest możliwe że kot ma Alę,
przecież to Ala jest jego właścicielką...

```

Sprawdzenie:

```
$ julia bit_stuffing.jl test decoded chk
Before encoding chekcsum (crc32c): 276902515
After decoding chekcsum (crc32c): 276902515
Are files the same? true
```

##### 2.7.2 Zepsute ramki:

Pozamieniam i pousuwam parę bitów z pliku "out" z poprzedniegu przykładu:

```
$ cat decoded
01111110010000010110110001100001001000000000110110101001011011000010010101111110
01111110011011010110000100100000011010110110000001100011110010101110111001111110
01111110011011110111010001100001000010101110101100100001111011001001001101111110
0111111001001011011011111110100001000001100110001001001111001000001101101111110
01111110011011010110000100100000010000010010101100111100011011000000100001111110
01111110011011001100010010011001000010100001010000010100001101000101011001111110
01111110010110100110000101110111011100110110011100011010101101101111001001111110
011111100111101001100101001000000111001110010100010111101111100001010001101111110
01111110011010011100010010011001001000000000001010001110110011101101111001111110
01111110011110100110000101110011011101000010010011111011101001110100111001111110
01111110011000010110111001100001011101110001000000001100100101001001101101111110
011111100110100101100001110001011000001000101100110001001110101111100010101111110
01111110011001010110110100100000011010101100001011000011101100001101010001111110
0111111001100001011010100100000011101001101010001110110000011110111100001111110
01111110011011110010000001001010011001010101010000011110011100011011110101111110
01111110011100110111010000100000011011011101011010011010101001100100000101111110
011111100110111110100010110111100011011001001100000101001001110110001011101111110
0110011001101001011101110110010100100000110000001001111101111100011010100001111110
01111110110001011011110001100101001000001100000001001010110100110000010101111110
01111110011010110110111101110100001000000001101101101100111100001001000001111110
01111110011011010110000100100000010000010010101100111100011011000000100001111110
01111110011011001100010010011001001011000001001000001000010111010110000001111110
011111100010000000001010011100000111001011000111100001101100001111101100101111110
01111110011110100110010101100011011010010010010000010010011110010110100101111110
011111100110010111000101101111000010000000101111100011011010100011010011101111110
01111110011101000110111100100000010000010000000010111001110111001011100101111110
01111110011011000110000100100000011010100100111101001101111000110101010101111110
011111100110010101110011011101000010000011111011101000000011001100101000101111110
011111100110101001100101011001110110111110010010101011101010011100110000001111110
0111111100010000001110111110000101100000101011001010110011110000110011001101111110
011111100110000111000101100110110110001111001010101000111010001011011111001111110
0111111001101001011000110110100101100101100010011111001111000101111101110001111110
011111100110110001101011110001001000010110110101110011111000101011101011101111110
01111110001011100010111000101110000010100100010101010101010001001010111001111110
```

```
$ julia bit_stuffing.jl out decoded dec
Error: Number of bits not a power of 8. Frame malformed, omitting.
Error: Number of bits not a power of 8. Frame malformed, omitting.
Error: Number of bits not a power of 8. Frame malformed, omitting.
Error: CRC32 check failed. Frame malformed, omitting.
Error: CRC32 check failed. Frame malformed, omitting.
Error: CRC32 check failed. Frame malformed, omitting.
  0.001191 seconds (1.48 k allocations: 90.422 KiB)
```

```
$ cat decoded
Ala ma kota
ma Alę
Zawsze się anawiałem jst możlże kot ma Alę,
przecież to Ala jest jegoaścicielką...
```

```
$ julia bit_stuffing.jl test decoded chk
Before encoding chekcsum (crc32c): 276902515
After decoding chekcsum (crc32c): 1537098958
Are files the same? false
```

Jak widać, program poprawnie wyłapuje błędne ramki i je odpowiednio pomija.

#### 3. Symulacja CSMA/CD

Do wykonania tego zadania, potrzebujemy zasymulować **łącze** pomiędzy nadającymi **urządzeniami**/**węzłami**, nadające **urządzenia**/**węzły**, **pakiety** przesyłane w sieci oraz **jednostkę czasu**, która określa co w danym momencie się dzieje w sieci.

W naszym przypadku symulowanym **łączem** będzie tablica, a dokładniej tablica tablic przesyłanych pakietów.

Każda **komórka** odpowiada położeniu danego urządzenia w sieci, tj. jeśli urządzenie podpięte jest do **komórki** 2, to urządzenie będzie "przesyłać pakiety" w tablicy na lewo i na prawo od **komórki** o indeksie 2.

Jednostką czasu w symulacji jest **krok**, a w danym kroku urządzenie może:

- spoczywać (nic nie przesyłać),
- rozpoczynać nadawanie,
- kontynuować nadawanie,
- kończyć nadawanie

W każdym kroku dany **pakiet** jest propagowany po łączu do **sąsiedniej komórki**/**komórek**, odpowiednie urządzenia są włączane/wyłączane oraz wykrywane oraz wykrywane są **kolizje**.

**Kolizja** następuje wtedy, kiedy urządzenie, które nadaje wykryje na swojej komórce pakiet pochodzący z innego urządzenia. W takiej sytuacji obecnie nadawany pakiet jest przerywany, a po sieci rozesłany zostaje **pakiet kolizyjny**, który informuje resztę węzłów o zaistnieniu **kolizji**.

**Urządzenia** nadające/**węzły** mają następujące atrybuty:

```julia
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
```

Gdzie:

- _name_ - nazwa węzła,
- _position_- pozycja w tablicy,
- _id_ - unikalne id urządzenia (dla prostoty _id_ = _position_),
- _idle_ - stan określający czy urządzenie nadaje (False), czy jest w spoczynku (True)
- _idle_time_ - czas oczekiwania, przed następnym nadawaniem,
- _collision_ - stan określający czy urządzenie wykryło kolizje,
- _detected_collisions_ - ilość kolizji zaobserwowana przez dane urządzenie przed prawidłowym przesłaniem całego pakietu,
- _frames_ - liczba pakietów/ramek przesyłana przez urządzenie, zanim przestanie w ogóle nadawać.

Pakiety określają tylko 3 wartości:

```julia
@kwdef mutable struct NodePacket
  node::Node = nothing
  collision_packet::Bool = node.collision
  direction::packet_directions
end
```

- _node_ - węzeł/urządzenie, od którego pochodzi pakiet,
- _collision_packet_ - stan określający, czy dany pakiet jest pakietem kolizyjnym,
- _direction_ - w którym kierunku rozchodzi się pakiet (na lewo, na prawo, w obie strony).

Każdy pakiet musi mieć wystarczającą wielkość, aby w przypadku kolizji można było ją wykryć przed przesłaniem kolejnego pakietu.

W takim razie pakiet, będzie miał wielkość wystarczającą, aby dwukrotnie przejść przez całe łącze, przed nadaniem kolejnego pakietu.
Innymi słowy, skoro nasz kabel ma długość **n** (**n**-elementowa tablica), to pakiet musi być nadawany przez czas odpowiadający propagacji przez **2n** komórek (a skoro 1 krok == propagacja na sąsiędnią komórkę, musimy wykonać **2n** kroków).

Naszą sieć symulujemy poprzez następne zmienne:

```julia
  @kwdef mutable struct Simulation
    cable_size::Int = 0
    cable::Vector{Vector{NodePacket}} = empty_cable(cable_size)
    available_positions::Dict{Int, Node} = Dict(i => Node() for i in 1:cable_size)
    broadcasting_nodes::Vector{Node} = []
    nodes_statistics::Dict{String, Dict{Symbol, Int}} = Dict()
  end
```

- _cable_size_ - ilość komórek w łączu (tablicy),
- _cable_ - tablica tablic pakietów, odpowiadająca temu, jakie pakiety znajdują się w danym fragmencie łącza w danym kroku,
- _available_positions_ - słownik, przechowujący węzły na danych komórkach łącza,
- _broadcasting_nodes_ - tablica węzłów, które musza jeszcze nadawać,
- _nodes_statistics_ - statystyki dotyczące symulacji.

W danym kroku symulacji:

- propagujemy istniejące sygały,
- sprawdzamy nadawanie z danych węzłów, tj. w razie potrzeby przerywamy nadawanie, rozpoczynamy nadawanie, kontynuujemy nadawanie, albo każemy węzłowi dalej czekać, zanim zacznie nadawać.

```julia
  function step(sim::Simulation, iteration::Int)
    next_state::Vector{Vector{NodePacket}} = empty_cable(sim.cable_size)
    propagate_packets!(sim, next_state)
    broadcasts!(sim, next_state, iteration)
    sim.cable = next_state
  end
```

##### 3.1 Przebieg symulacji

W pliku main.jl znajduje się przykładowe przygotowanie i uruchomienie symulacji.

Przyjmijmy następujące atrybuty:

```julia
cable_size = 10
# Węzły:
Node(name="A", position=1, idle_time=0, frames=3))
Node(name="B", position=3, idle_time=5, frames=2))
Node(name="C", position=10, idle_time=10, frames=1))
Node(name="D", position=7, idle_time=0, frames=3))
Node(name="E", position=8, idle_time=0, frames=0))
```

Nasza sieć będzie wyglądać wtedy tak:

```
  A       B               D   E       C
|[ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ]|
```

Uruchomienie symulacji:

```
$julia main.jl [mode]
```

Gdzie mode można ustawić jako "slow", dzięki czemu możemy obserwować symulacje krok po kroku, po wciśnięciu klawisza Enter.

Po wykonanej symulacji program zapisuje jej przebieg do pliku nazwazmiennej_out.log:

```
Iteration: 1
A started broadcasting
B is waiting
C is waiting
D started broadcasting
Cable after 1:
|[ ][ ][ ][ ][ ][ ][ ][ ][ ][ ]|

Iteration: 2
A continues broadcasting
B is waiting
C is waiting
D continues broadcasting
Cable after 2:
|[A][ ][ ][ ][ ][ ][D][ ][ ][ ]|

Iteration: 3
A continues broadcasting
B is waiting
C is waiting
D continues broadcasting
Cable after 3:
|[A][A][ ][ ][ ][D][D][D][ ][ ]|

Iteration: 4
A continues broadcasting
B is waiting
C is waiting
D continues broadcasting
Cable after 4:
|[A][A][A][ ][D][D][D][D][D][ ]|

Iteration: 5
A continues broadcasting
B is waiting
C is waiting
D continues broadcasting
Cable after 5:
|[A][A][A][A,D][D][D][D][D][D][D]|

Iteration: 6
A continues broadcasting
B is waiting
C is waiting
D continues broadcasting
Cable after 6:
|[A][A][A,D][A,D][A,D][D][D][D][D][D]|

Iteration: 7
A continues broadcasting
B is waiting
C is waiting
D continues broadcasting
Cable after 7:
|[A][A,D][A,D][A,D][A,D][A,D][D][D][D][D]|

Iteration: 8
A detected a collision, sending collision signal
A continues broadcasting
B is waiting
C is waiting
D detected a collision, sending collision signal
D continues broadcasting
Cable after 8:
|[D,A][A,D][A,D][A,D][A,D][A,D][A,D][D][D][D]|

Iteration: 9
A continues broadcasting
B is waiting
C is waiting
D continues broadcasting
Cable after 9:
|[D,A][A!,D][A,D][A,D][A,D][A,D][A,D][A,D][D][D]|

Iteration: 10
A continues broadcasting
B is waiting
C is waiting
D continues broadcasting
Cable after 10:
|[D,A][A!,D][A!,D][A,D][A,D][A,D][A,D][A,D][A,D][D]|

[...]
```

Aby zmienić atrybuty symulacji, wystarczy zmienić kod w main.jl.

Funkcja:

- Simulation(cable_size) - tworzy symulacje o danej wielkości łącza,
- new_node(name, position, idle_time, frames) - tworzy nowy node,
- add_node!(simulation, node) - dodaje node do symulacji,
- run(simulation, slow=mode) - uruchamia symulacje w danym mode ("slow",albo domyślnie bez przerywania),
- statistics(simulation) - drukuje statystyki węzłów po symulacji.

Wszystkie funkcje, potrzebne do wykonania symulacji, przechowywane są w module `CSMA_CD_Simulation` w pliku _simulation.jl_,
a struktury węzła i pakietu w pliku _node_.jl.

Moduł `CSMA_CD_Simulation` eksportuje także wektor `messages` zawierający logi po wykonaniu symulacji.
