module Percentiles exposing (fetch, Percentiles, Percentile,
  toList, toPercentilesList, toDatesList, toLineData, getPercentile)

import Http
import Json.Decode as Decode exposing (Decoder)
import RemoteData exposing (WebData, RemoteData(..))
import Time
import String
import List
import Tuple
import Utilities exposing (loggingDecoder)
import PerfType exposing (PerfType)

-- my
import Point exposing (Point, TimePoint)

-- for testing

import Browser
import Html exposing (Html, text, pre)


type Percentiles
  = Percentiles (List Percentile)

toList : Percentiles -> List Percentile
toList (Percentiles list) =
  list

type Percentile
  = Percentile
    { percentile : Float
    , datedRatings : List DatedRating
    }

type alias DatedRating =
  { date : Time.Posix
  , rating : Float
  }

toPercentilesList : Percentiles -> List Float
toPercentilesList (Percentiles percentileList) =
  List.map
    (\(Percentile percentile) -> percentile.percentile)
    percentileList

toDatesList : Percentiles -> List Time.Posix
toDatesList (Percentiles percentilesList) =
  List.map
    (\(Percentile percentile) -> percentile.datedRatings)
    percentilesList
    |> List.head
    |> Maybe.withDefault []
    |> List.map .date

toLineData : Percentile -> List TimePoint
toLineData (Percentile percentile) =
  List.map
    (\datedRating ->
      TimePoint
        datedRating.date
        datedRating.rating
    )
    percentile.datedRatings

getPercentile : Percentile -> Float
getPercentile (Percentile percentile) =
  percentile.percentile



decoder : Decoder Percentiles
decoder =
  Decode.map Percentiles (Decode.list percentileDecoder)

percentileDecoder : Decoder Percentile
percentileDecoder =
  Decode.map2
    (\percentile datedRating ->
      Percentile
        { percentile = percentile
        , datedRatings = datedRating
        }
    )
    ( Decode.field "percentile" Decode.float )
    ( Decode.field "datedRatings" (Decode.list datedRatingDecoder) )

datedRatingDecoder : Decoder DatedRating
datedRatingDecoder =
  Decode.map2 DatedRating
    ( Decode.field "date" ( Decode.map Time.millisToPosix Decode.int ) )
    ( Decode.field "rating" Decode.float )

url : PerfType -> String
url perfType =
  "http://localhost:8080/api/percentiles/" ++ (PerfType.toString perfType)

fetch : PerfType -> (WebData Percentiles -> msg)-> Cmd msg
fetch perfType msgCons =
  Http.get
    { url = url perfType
    , expect =
        Http.expectJson
          (RemoteData.fromResult >> msgCons)
          (loggingDecoder decoder)
    }


-- testing


main =
  Browser.element
    { init = init
    , update = update
    , view = view
    , subscriptions = subs
    }

type alias Model = WebData Percentiles

init () =
  ( Loading
  , fetch PerfType.default PercentilesResponse)

type Msg
  = PercentilesResponse Model

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    PercentilesResponse response ->
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


