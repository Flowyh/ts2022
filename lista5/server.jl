using HTTP, Sockets

const ROUTER = HTTP.Router()

# Zmień skrypt (lub napisz własny serwer w dowolnym języku programowania) tak aby wysyłał do klienta nagłówek jego żądania.
println("Server running on port 8001 . . .")

function print_header(header)
  result = ""
  for pair in header
    result *= "$(pair[1]): $(pair[2])\n"
  end
  return result
end
HTTP.@register(ROUTER, "GET", "/header", req->HTTP.Response(200, "\n$(print_header(HTTP.Messages.headers(req)))"))

# Zmień skrypt (lub napisz własny serwer w dowolnym języku programowania) 
# tak aby obsugiwał żądania klienta do prostego tekstowego serwisu WWW 
# (kilka statycznych ston z wzajemnymi odwołaniami) zapisanego w pewnym katalogu dysku lokalnego komputera na którym uruchomiony jest skrypt serwera.
HTTP.@register(ROUTER, "GET", "/", req->HTTP.Response(read("./index.html")))
HTTP.@register(ROUTER, "GET", "/papuez", req->HTTP.request("GET", "https://media.discordapp.net/attachments/868291982768894013/889955128252178512/papiez_call_me.gif"))
HTTP.@register(ROUTER, "GET", "/fajnefotki", req->HTTP.Response(read("./fajne_fotki.html")))
HTTP.@register(ROUTER, "GET", "/kotek", req->HTTP.Response(read("./kotekasi.jpg")))
HTTP.@register(ROUTER, "GET", "/sprawozdanie", req->HTTP.Response(read("./sprawozdanie/sprawozdanie_ts_5.html")))
HTTP.@register(ROUTER, "GET", "/kotek2", req->HTTP.request("GET", "https://zspkotowiecko.noweskalmierzyce.pl/sites/zspkotowiecko.noweskalmierzyce.pl/files/zdjecia/goni_motylka_fi_orig.gif"))
HTTP.@register(ROUTER, "GET", "/lorem", req->HTTP.Response(read("./lorem")))
HTTP.@register(ROUTER, "GET", "/bye", req->HTTP.Response(200, "Bye!"))
HTTP.@register(ROUTER, "GET", "/*", req->HTTP.Response(404, "Not found!"))
HTTP.serve(ROUTER, Sockets.localhost, 8001)