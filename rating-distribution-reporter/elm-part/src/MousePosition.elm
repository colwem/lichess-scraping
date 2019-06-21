module MousePosition exposing (decoder)

import Json.Decode as Decode exposing (Decoder)
import Point exposing (Point)

decoder : Decoder Point
decoder =
  Decode.map2 Point
    (Decode.field "clientX" Decode.float)
    (Decode.field "clientY" Decode.float)
