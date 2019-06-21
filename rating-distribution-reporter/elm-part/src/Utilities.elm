module Utilities exposing (getClosest, loggingDecoder, maybeShow)

-- import List
import List
import List.Extra as List
import Maybe
import Json.Decode as Decode exposing (Decoder)

getClosest : ( a -> number ) -> number -> List a -> Maybe a
getClosest accessor target list =
  List.minimumBy (\x -> accessor x - target |> abs) list


loggingDecoder : Decoder a -> Decoder a
loggingDecoder realDecoder =
    Decode.value
        |> Decode.andThen
            (\value ->
                case Decode.decodeValue realDecoder value of
                    Ok decoded ->
                        Decode.succeed decoded

                    Err error ->
                        Decode.fail <| Debug.log "decode error" <| Decode.errorToString error
            )

maybeShow : (a -> b) -> Maybe a -> List b
maybeShow f maybe =
  maybe
    |> Maybe.map (f >> List.singleton)
    |> Maybe.withDefault []
