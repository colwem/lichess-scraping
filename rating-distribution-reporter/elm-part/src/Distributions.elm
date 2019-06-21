module Distributions exposing (DatedDistribution, Distribution, fetch,
  closestDistribution)

import Http
import Json.Decode as Decode exposing (Decoder)
import RemoteData exposing (WebData, RemoteData(..))
import Time
import String
import List
import Tuple

-- My
import Utilities exposing (getClosest)
import PerfType exposing (PerfType)

-- for testing

import Browser
import Html exposing (Html, text, pre)

--

url : PerfType -> String
url perfType =
  "http://localhost:8080/api/distributions/" ++ (PerfType.toString perfType)

fetch : PerfType -> (WebData (List DatedDistribution) -> msg)-> Cmd msg
fetch perfType msgCons =
  Http.get
    { url = url perfType
    , expect =
        Http.expectJson
          (RemoteData.fromResult >> msgCons)
          decoder
    }

type alias Distribution
  = List Float

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
  Decode.list Decode.float


closestDistribution : Time.Posix -> (List DatedDistribution)-> Distribution
closestDistribution date datedDistributions=
  getClosest
    (\dd -> Time.posixToMillis dd.date)
    (Time.posixToMillis date)
    datedDistributions
    |> Maybe.withDefault
      (DatedDistribution (Time.millisToPosix 0) [])
    |> .distribution

-- testing

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

main =
  Browser.element
    { init = init
    , update = update
    , view = view
    , subscriptions = subs
    }

type alias Model = WebData (List DatedDistribution)

init () =
  ( Loading
  , fetch PerfType.default DistributionResponse)

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


