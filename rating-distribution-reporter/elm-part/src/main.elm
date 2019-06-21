module Main exposing (main)

import Browser
import Browser.Events
import Browser.Dom
import Task

import Http
import Html exposing (..)
import Html.Attributes as Attributes exposing (..)
import Html.Events as Events exposing (onSubmit)

import TypedSvg exposing (svg)
import TypedSvg.Attributes
import TypedSvg.Types exposing (Length(..))

import Time
import Json.Decode as Decode
import RemoteData exposing (WebData, RemoteData(..))

-- My
import UserRatingHistory exposing (UserRatingHistory, fetch, userRatings,
  userRating)
import Percentiles exposing (Percentiles)
import Distributions exposing (DatedDistribution)
import DistributionChart
import PercentilesChart
import Utilities exposing (maybeShow)
import Point exposing (Point)
import MousePosition
import PerfType exposing (PerfType)

type alias Model =
  { usernameInput : String
  , username : Maybe String
  , userRatingHistory : WebData UserRatingHistory
  , percentiles : WebData Percentiles
  , distributions : WebData (List DatedDistribution)
  , dateSelected : Maybe Time.Posix
  , selectingDate : Bool
  , perfTypeSelected : PerfType
  , mousePosition : Maybe Point
  , showDistributionMouse : Bool
  , showPercentilesMouse : Bool
  , percentilesMouseRelative : Maybe Point
  , distributionMouseRelative : Maybe Point
  }

type Username = Username String




init : () -> (Model, Cmd Msg)
init _ =
  let
      initialPerfType = PerfType.Blitz
  in
      ( { usernameInput = ""
        , username = Nothing
        , userRatingHistory = NotAsked
        , percentiles = Loading
        , distributions = Loading
        , dateSelected = Nothing
        , selectingDate = False
        , perfTypeSelected = initialPerfType
        , mousePosition = Nothing
        , showDistributionMouse = False
        , showPercentilesMouse = False
        , percentilesMouseRelative = Nothing
        , distributionMouseRelative = Nothing
        }
      , Cmd.batch
          [ Percentiles.fetch initialPerfType PercentilesResponse
          , Distributions.fetch initialPerfType DistributionsResponse
          ]
      )

type Msg
  = UsernameInput String
  | FetchUserRatingHistory
  | UserRatingHistoryResponse String (WebData UserRatingHistory)
  | DistributionsResponse (WebData (List DatedDistribution))
  | PercentilesResponse (WebData Percentiles)
  | MouseMove Point
  | DateSelected Time.Posix
  | StartSelectingDate
  | StopSelectingDate
  | PerfTypeSelected PerfType
  | ShowPercentilesMouse
  | HidePercentilesMouse
  | ShowDistributionMouse
  | HideDistributionMouse
  | PercentilesMouseRelative (Result Browser.Dom.Error Point)
  | DistributionMouseRelative (Result Browser.Dom.Error Point)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    UsernameInput usernameInput ->
      ( { model | usernameInput = usernameInput }
      , Cmd.none
      )

    FetchUserRatingHistory ->
      if usernameInputValid model then
        ( { model | userRatingHistory = Loading }
        , UserRatingHistory.fetch model.usernameInput UserRatingHistoryResponse
        )
      else
        ( model, Cmd.none )


    UserRatingHistoryResponse username response ->
      ( { model | userRatingHistory = response, username = Just username }
      , Cmd.none
      )

    PerfTypeSelected perfType ->
      ( { model | perfTypeSelected = perfType }
      , Cmd.batch
        [ Percentiles.fetch perfType PercentilesResponse
        , Distributions.fetch perfType DistributionsResponse
        ]
      )

    PercentilesResponse response ->
      ( { model | percentiles = response }
      , Cmd.none
      )

    DistributionsResponse response ->
      ( { model | distributions = response }
      , Cmd.none
      )

    MouseMove point ->
      ( { model | mousePosition = Just point }
      , Cmd.batch
        [ mouseRelative "distribution-chart" point DistributionMouseRelative
        , mouseRelative "percentiles-chart" point PercentilesMouseRelative
        ]
      )

    DateSelected date ->
      ( { model | dateSelected = Just date }
      , Cmd.none
      )

    StartSelectingDate ->
      ( { model | selectingDate = True
        , dateSelected = updateDateSelected { model | selectingDate = True }
        }
      , Cmd.none
      )

    StopSelectingDate ->
      ( { model | selectingDate = False }
      , Cmd.none
      )

    ShowPercentilesMouse ->
      ( { model | showPercentilesMouse = True }
      , Cmd.none
      )

    HidePercentilesMouse ->
      ( { model | showPercentilesMouse = False }
      , Cmd.none
      )

    ShowDistributionMouse ->
      ( { model | showDistributionMouse = True }
      , Cmd.none
      )

    HideDistributionMouse ->
      ( { model | showDistributionMouse = False }
      , Cmd.none
      )

    PercentilesMouseRelative result ->
      case result of
        Ok point ->
          ( { model | percentilesMouseRelative = Just point
            , dateSelected =
                updateDateSelected
                  { model | percentilesMouseRelative = Just point }
            }
          , Cmd.none
          )

        _ -> ( model, Cmd.none )

    DistributionMouseRelative result ->
      case result of
        Ok point ->
          ( { model | distributionMouseRelative = Just point }
          , Cmd.none
          )

        Err _ -> ( model, Cmd.none )

updateDateSelected : Model -> Maybe Time.Posix
updateDateSelected model =
  case (model.percentiles, model.selectingDate, model.percentilesMouseRelative) of
    (Success percentiles, True, Just point) ->
      Just (PercentilesChart.xToDate percentiles point.x)

    _ ->
      model.dateSelected

-- getDistribution : DataModel -> Time.Posix -> Distribution
-- getDistribution dataModel date =
  -- let
      -- defaultDistribution = [0]
  -- in
  -- List.find (\x -> x.date == date) dataModel
    -- |> Maybe.withDefault defaultDistribution

-- getValidDate : Time.Posix -> DataModel -> Time.Posix
-- getValidDate date dataModel =
  -- let
      -- dataModelToDateList dm =
        -- List.map ( \x -> x.date ) dm
  -- in
      -- getClosest identity model.date (dataModelToDateList dataModel)

mouseRelative :
        String -> Point -> (Result Browser.Dom.Error Point -> msg)
        -> Cmd msg
mouseRelative elementId mousePosition msg =
  Browser.Dom.getElement elementId
    |> Task.map
      (\e ->
        Point
          ( mousePosition.x - e.element.x )
          ( mousePosition.y - ( e.element.y - e.viewport.y))
      )
    |> Task.attempt msg

relativePosition : Maybe Point -> Maybe Point -> Maybe Point
relativePosition a b =
  case (a, b) of
    (Just pointA, Just pointB) ->
      Just <| Point.diff pointA pointB

    _ -> Nothing

sizeAttributes : List (Attribute msg)
sizeAttributes =
  [ TypedSvg.Attributes.height ( Px 500 )
  , TypedSvg.Attributes.width ( Px 500  )
  , TypedSvg.Attributes.viewBox 0 0 500 500
  ]

view : Model -> Html Msg
view model =
  let
      userRating =
        case (model.userRatingHistory, model.dateSelected) of
          (Success userRatingHistory, Just dateSelected)->
            Just <|
              (UserRatingHistory.userRating
                userRatingHistory
                model.perfTypeSelected
                dateSelected)

          _ -> Nothing

      userRatings =
        case model.userRatingHistory of
          Success userRatingHistory ->
            Just <|
              UserRatingHistory.userRatings
                userRatingHistory
                model.perfTypeSelected

          _ -> Nothing

      distributionChart =
        case (model.distributions, model.dateSelected) of
          (Success distributions, Just dateSelected) ->
            DistributionChart.view
              ( DistributionChart.Model
                  (Distributions.closestDistribution dateSelected distributions)
                  userRating
                  model.distributionMouseRelative
                  model.showDistributionMouse
              )
              ShowDistributionMouse
              HideDistributionMouse

          (Loading, _ ) ->
            text "Loading Distributions..."

          (Success distributions, Nothing ) ->
            text "Select a date to view it's distribution"

          _ -> text "???"

      percentilesChart =
        case model.percentiles of
          Success percentiles ->
            PercentilesChart.view
              ( PercentilesChart.Model
                  percentiles
                  userRatings
                  model.percentilesMouseRelative
                  model.showPercentilesMouse
                  model.dateSelected
              )
              StartSelectingDate
              StopSelectingDate
              ShowPercentilesMouse
              HidePercentilesMouse

          Loading -> text "Loading Percentiles..."

          _ -> text "???"


  in
      div []
        [ div [ class "text-center" ]
          [ h1 []
            [ text "Lichess "
            , div [ class "d-inline-block" ]
              [ viewPerfTypeSelector model.perfTypeSelected]
            , text " Historical Rating Statistics"
            ]
          ]
        , Html.div [][ percentilesChart ]
        , Html.div [][ distributionChart ]
        , viewUserForm model
        ]

usernameInputValid : Model -> Bool
usernameInputValid model =
  case model.username of
    Just username ->
      not (model.usernameInput == "" || model.usernameInput == username)

    Nothing ->
      not (model.usernameInput == "")

viewUserForm : Model -> Html Msg
viewUserForm model =
  let
      disabled =
        if usernameInputValid model
        then ""
        else "disabled"
  in
      div []
        [ Html.form [ onSubmit FetchUserRatingHistory ]
          [ div [class "input-group mb-3"]
            [ div [class "input-group-prepend"]
              [ button
                [ class <| "btn btn-primary mb-2 " ++ disabled  ]
                [ text "Fetch User Rating History" ]
              ]
            , (viewUserInput model.usernameInput)
            ]
          ]
        , viewUsername model
        ]

viewUserInput : String -> Html Msg
viewUserInput usernameInput =
  input
    [ placeholder "Lichess Username"
    , value usernameInput
    , class "form-control mb-2 mr-sm-2"
    , Events.onInput UsernameInput
    ]
    []

viewUsername : Model -> Html Msg
viewUsername model =
  case (model.username, model.userRatingHistory) of
    (Just username, Failure failure) ->
      div [ class "alert alert-danger" ]
        [ text
          ("Rating History for \""
            ++ username ++ "\" could not be found")
        ]

    (Just username, Success ratingHistory) ->
      div [ class "alert alert-primary" ]
        [ text
          ("Showing User Rating History for \""
            ++ username ++ "\"")
        ]

    _ -> text ""

onPerfTypeChange : (PerfType -> msg) -> Attribute msg
onPerfTypeChange handler =
  Events.on "change"
    <| Decode.map handler
    <| Decode.map PerfType.fromString
    <| Decode.at ["target", "value"] Decode.string

viewPerfTypeSelector : PerfType -> Html Msg
viewPerfTypeSelector perfType =
  Html.select
    [ onPerfTypeChange PerfTypeSelected ] <|
    List.map ( viewPerfTypeOption perfType ) PerfType.perfTypes

viewPerfTypeOption : PerfType -> PerfType -> Html Msg
viewPerfTypeOption current perfType =
  Html.option
    [ Attributes.selected (current == perfType)
    , value (PerfType.toString perfType)]
    [ text (PerfType.toDisplay perfType) ]


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [ Browser.Events.onMouseMove (Decode.map MouseMove MousePosition.decoder)
  , Browser.Events.onMouseUp (Decode.succeed StopSelectingDate)
  ]

-- Sub.batch
  -- [ Sub.map (PercentilesChartMsg) PercentilesChart.subscriptions
  -- , Sub.map (DistributionChartMsg) DistributionChart.subscriptions
  -- ]


main =
  Browser.element
    { init = init
    , update = update
    , view = view
    , subscriptions = subscriptions
    }
