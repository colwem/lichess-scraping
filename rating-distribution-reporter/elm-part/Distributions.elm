module Distributions exposing (fetch, DatedDistribution)

import Http
import Json.Decode as Decode exposing (Decoder)
import RemoteData exposing (WebData, RemoteData(..))
import Time
import String
import List
import Tuple

-- for testing

import Browser
import Html exposing (Html, text, pre)

--

url : String -> String
url perfType =
  "http://localhost:8080/api/distributions/" ++ perfType

fetch : String -> (RemoteData Http.Error (List DatedDistribution) -> msg)-> Cmd msg
fetch perfType msgCons =
  Http.get
    { url = url perfType
    , expect =
        Http.expectJson
          (RemoteData.fromResult >> msgCons)
          (loggingDecoder decoder)
    }

type Distribution
  = Distribution (List Int)

type alias DatedDistribution =
  { date : Time.Posix
  , distribution : Distribution
  }

decoder : Decoder (List DatedDistribution)
decoder =
  Decode.list datedDistributionDecoder

datedDistributionDecoder : Decoder DatedDistribution
datedDistributionDecoder =
  Decode.map2 DatedDistribution
    ( Decode.field "date" ( Decode.map Time.millisToPosix Decode.int ) )
    ( Decode.field "distribution" distributionDecoder )

distributionDecoder : Decoder Distribution
distributionDecoder =
  Decode.map Distribution ( Decode.list Decode.int )

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

-- testing


main =
  Browser.element
    { init = init
    , update = update
    , view = view
    , subscriptions = subs
    }

type alias Model = RemoteData Http.Error (List DatedDistribution)

init () =
  ( Loading
  , fetch "blitz" DistributionResponse)

type Msg
  = DistributionResponse Model

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    DistributionResponse response ->
      ( response
      , Cmd.none
      )

view : Model -> Html Msg
view model =
  let
      happy = Debug.log "ok" model
  in
      case model of
        Loading ->
          text "loading"

        Success list ->
          text ("success" ++ Debug.toString list)

        Failure err ->
          pre []
            [ text ("Error: " ++ Debug.toString model |> unEscape)]

        NotAsked ->
          text "Initializing"


unEscape string =
  List.foldl (\a b -> String.replace (Tuple.first a) (Tuple.second a) b)
    string
    [ ("\\n", "\n")
    , ("\\\"", "\"")]


subs : Model -> Sub Msg
subs model =
  Sub.none


