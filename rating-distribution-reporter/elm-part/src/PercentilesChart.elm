module PercentilesChart exposing (view, Model, xToDate)

-- elm/core
import Browser
import Browser.Dom
import Html exposing (Html, div, text)
import Html.Attributes exposing (id)
import Task
import List
import List.Extra as List
import String
import Debug
import Time

-- RemoteData
import RemoteData exposing (WebData, RemoteData(..))

-- Json
import Json.Decode as Decode exposing (Decoder)

-- Color
import Color
import Color.Manipulate exposing (fadeOut)

-- elm-visualization
import Axis
import Path exposing (Path)
import SubPath exposing (SubPath)
import Scale exposing (ContinuousScale)
import Scale.Color
import Shape
import Statistics

-- typed-svg
import TypedSvg exposing (g, svg)
import TypedSvg exposing (svg, circle, rect, text_)
import TypedSvg.Attributes exposing
  (viewBox, cx, cy, r, fill, strokeWidth, stroke, height, width
  , class, transform, fillOpacity, x1, x2, y1, y2, strokeDasharray
  , textAnchor)
import TypedSvg.Attributes.InPx exposing (strokeWidth)
import TypedSvg.Core exposing (Svg, Attribute)
import TypedSvg.Types exposing (Fill(..), Transform(..), Length(..)
  , Opacity(..), AnchorAlignment(..))
import TypedSvg.Events exposing (onMouseDown, onMouseUp, onMouseOver, onMouseLeave)
import VirtualDom

-- Css
import Css
import Html.Styled
import Css.Global as Css
import Svg.Styled.Attributes as SvgCss

import DateFormat

-- My
import Utilities exposing (loggingDecoder, maybeShow)
import Percentiles
import MousePosition
import Point exposing (TimePoint)
import PerfType

chartDimensions : { width : Float, height : Float }
chartDimensions =
  { width = 900
  , height = 300}

margins : { top : Float, bottom : Float, right : Float, left : Float }
margins =
  { top = 50
  , bottom = 30
  , right = 50
  , left = 50
  }

type alias Point =
  { x : Float
  , y : Float
  }

type alias Model =
  { percentiles : Percentiles.Percentiles
  , userRatings : Maybe (List {date : Time.Posix, rating : Float})
  , mousePosition : Maybe Point
  , showMouse : Bool
  , dateSelected : Maybe Time.Posix
  }

curve : List ( Float, Float ) -> SubPath
curve =
  Shape.linearCurve

ratingScale : ContinuousScale Float
ratingScale =
  Scale.linear (chartDimensions.height, 0) (800, 2800)

colorScale : Float -> Color.Color
colorScale p =
  Scale.Color.plasmaInterpolator (p * 0.8 + 0.1)

getDateScale : List Time.Posix -> ContinuousScale Time.Posix
getDateScale dates =
  let
      range =
        (0, chartDimensions.width)

      domain =
        Statistics.extentBy
          (\date -> Time.posixToMillis date)
          dates
          |> Maybe.withDefault
            (Time.millisToPosix 0, Time.millisToPosix 0)
  in
      Scale.time Time.utc range domain

xToDate : Percentiles.Percentiles -> Float -> Time.Posix
xToDate percentiles x =
  (Percentiles.toDatesList percentiles
  |> getDateScale
  |> Scale.invert) x

line : ContinuousScale a -> ContinuousScale b -> List {x: a, y: b} -> Path.Path
line xScale yScale model =
  let
      lineData point =
        Just ( Scale.convert xScale point.x, Scale.convert yScale point.y)
  in
      List.map lineData model
        |> Shape.line curve


viewPercentileLine : ContinuousScale Time.Posix -> Percentiles.Percentile -> Svg msg
viewPercentileLine dateScale percentile =
  let
      model = Percentiles.toLineData percentile
  in
      Path.element ( line dateScale ratingScale model )
        [ stroke (colorScale ((Percentiles.getPercentile percentile) / 100))
        , class ["line"]
        ]

-- Y Axis
viewRatingAxis : Svg msg
viewRatingAxis =
  g [ transform [Translate 0 0]]
    [ Axis.left
      [ Axis.tickCount 20
      ]
      ratingScale
    ]

viewRatingGrid : Svg msg
viewRatingGrid =
  g [ class ["grid"], transform [Translate 0 0]]
    [ Axis.left
      [ Axis.tickCount 20
      , Axis.tickFormat <| always ""
      , Axis.tickSizeInner <| negate chartDimensions.width
      , Axis.tickSizeOuter 0
      ]
      ratingScale
    ]

dateFormat : Time.Posix -> String
dateFormat =
  DateFormat.format
    [ DateFormat.dayOfMonthNumber
    , DateFormat.text " "
    , DateFormat.monthNameAbbreviated
    , DateFormat.text " '"
    , DateFormat.yearNumberLastTwo
    ]
    Time.utc

viewDateAxis : ContinuousScale Time.Posix -> Svg msg
viewDateAxis scale =
  g [ transform [Translate 0 0]]
    [ Axis.top
        [ Axis.tickCount 10
        , Axis.tickPadding 10
        , Axis.tickFormat dateFormat
        ]
        scale
    ]

viewDateGrid : ContinuousScale Time.Posix -> Svg msg
viewDateGrid scale =
  g [ class ["grid"], transform [Translate 0 (chartDimensions.height)]]
    [ Axis.bottom
      [ Axis.tickCount 10
      , Axis.tickFormat <| always ""
      , Axis.tickSizeInner <| negate chartDimensions.height
      , Axis.tickSizeOuter 0
      ]
      scale
    ]

horizontalLineAttributes y =
  [ x1 ( Px 0 )
  , x2 ( Px chartDimensions.width )
  , y1 y
  , y2 y
  ]

verticalLineAttributes x =
  [ x1 x
  , x2 x
  , y1 ( Px 0 )
  , y2 ( Px chartDimensions.height )
  ]

viewMouseLines : Point -> List (Svg msg)
viewMouseLines point =
  let
      commonAttr =
        [ strokeDasharray "4,4"
        , stroke (fadeOut 0.8 Color.black)
        , strokeWidth 3
        ]

      xline =
        TypedSvg.line
          (verticalLineAttributes (Px point.x) ++ commonAttr) []

      yline =
        TypedSvg.line
          (horizontalLineAttributes (Px point.y) ++ commonAttr) []
  in
      [ xline
      , yline ]

viewDateLine : ContinuousScale Time.Posix -> Time.Posix-> Svg msg
viewDateLine scale date =
  let
      x = Px (Scale.convert scale date )
  in
      TypedSvg.line
        ((verticalLineAttributes x) ++ [ class ["line", "date-line"] ])  []


viewDateText : ContinuousScale Time.Posix -> Time.Posix-> Svg msg
viewDateText scale date =
  text_
    [ transform
      [Translate (Scale.convert scale date) (chartDimensions.height + 20) ]
    , textAnchor AnchorMiddle
    ]
    [ text (dateFormat date)
    ]

viewDateSelectGrabber : msg -> ContinuousScale Time.Posix -> Maybe Time.Posix-> Svg msg
viewDateSelectGrabber startSelectingDate scale date =
  let
      x = Maybe.map (Scale.convert scale) date |> Maybe.withDefault 0
  in
      circle
        [ cx (Px x)
        , cy (Px chartDimensions.height)
        , r (Px 10)
        , fill (Fill Color.grey)
        , onMouseDown startSelectingDate]
        []

extend = (++)

viewMouseOverlay : msg -> msg -> msg -> Svg msg
viewMouseOverlay startSelectingDate showMouse hideMouse =
  let
      onClick = []
      -- onClick =
        -- mouseDate
          -- |> Maybe.map
            -- (dateSelected >> TypedSvg.Events.onClick >> List.singleton)
          -- |> Maybe.withDefault []
  in
      rect
        ([ id "percentiles-chart"
        , height ( Px chartDimensions.height )
        , width ( Px chartDimensions.width )
        , fillOpacity  ( Opacity 0 )
        , onMouseOver showMouse
        , onMouseLeave hideMouse
        , onMouseDown startSelectingDate
        ] |> extend onClick)
        []

viewUserRatingLine : ContinuousScale Time.Posix
  -> List {date : Time.Posix, rating : Float}
  -> Svg msg
viewUserRatingLine dateScale model =
  let
      lineModel =  List.map (\d -> {x = d.date, y = d.rating }) model
  in
      Path.element ( line dateScale ratingScale lineModel )
        [ class ["user-rating-line"] ]

viewLegend : List Float -> Svg msg
viewLegend percentiles =
  TypedSvg.Core.text "todo"

view : Model -> msg -> msg -> msg -> msg -> Html msg
view model startSelectingDate stopSelectingDate showMouse hideMouse =
  let
      dateScale =
        getDateScale (Percentiles.toDatesList model.percentiles)

      mouseLines =
        case (model.showMouse, model.mousePosition) of
          (True, Just point) ->
              viewMouseLines point

          _ -> []

      mouseDate =
        Maybe.map .x model.mousePosition
          |> Maybe.map (Scale.invert dateScale)

      dateLine =
        model.dateSelected
          |> Maybe.map
            ( viewDateLine dateScale
            >> List.singleton)
          |> Maybe.withDefault []


      dateText =
        model.dateSelected
          |> Maybe.map
            ( viewDateText dateScale
            >> List.singleton)
          |> Maybe.withDefault []

  in
      svg
        sizeAttributes
        [ g [ id "percentiles-chart-g"
            , transform [Translate margins.left margins.top ]
            ] <|
            [ viewRatingAxis
            , viewDateAxis dateScale
            , viewRatingGrid
            , viewDateGrid dateScale ]
            ++ maybeShow (viewDateLine dateScale) model.dateSelected
            ++ maybeShow (viewDateText dateScale) model.dateSelected
            ++  List.map
                  (viewPercentileLine dateScale)
                  (Percentiles.toList model.percentiles)
            ++ maybeShow (viewUserRatingLine dateScale) model.userRatings
            ++ [ viewLegend (Percentiles.toPercentilesList model.percentiles) ]
            ++ mouseLines
            ++ [ viewDateSelectGrabber startSelectingDate dateScale model.dateSelected ]
            ++ [viewMouseOverlay
                  startSelectingDate
                  showMouse
                  hideMouse]
        ]


-- testing

type Msg
  = MouseMove Point
  | MouseRelative (Result Browser.Dom.Error Point)
  | ShowMouse
  | HideMouse
  | StartSelectingDate
  | StopSelectingDate
  | PercentilesResponse (WebData Percentiles.Percentiles)


onMouseMove : (Point -> msg) -> Attribute msg
onMouseMove msgConstructor =
  TypedSvg.Events.on "mousemove"
    <| VirtualDom.Normal
    <| Decode.map msgConstructor MousePosition.decoder

testUpdate : Msg -> TestModel -> (TestModel, Cmd Msg)
testUpdate msg model =
  case msg of
    PercentilesResponse response ->
      ( { model | percentiles = response }
      , Cmd.none
      )

    MouseMove point ->
      ( model
      , Browser.Dom.getElement "percentilesOverlay"
        |> Task.map
            (\e ->
              Point (point.x - e.element.x) (point.y - e.element.y)
            )
        |> Task.attempt MouseRelative
      )

    MouseRelative result ->
      case result of
        Ok point ->
          ({ model | mousePosition = Just point }
          , Cmd.none
          )

        Err (Browser.Dom.NotFound error) ->
          (Debug.log error { model | mousePosition = Nothing }, Cmd.none)

    HideMouse ->
      ({ model | showMouse = False }
      , Cmd.none
      )

    ShowMouse ->
      ({ model | showMouse = True }
      , Cmd.none
      )

    StartSelectingDate ->
      ( model
      , Cmd.none
      )

    StopSelectingDate ->
      ( model
      , Cmd.none
      )


type alias TestModel =
  { percentiles : WebData Percentiles.Percentiles
  , userRatings : Maybe (List {date : Time.Posix, rating : Float})
  , mousePosition : Maybe Point
  , showMouse : Bool
  , dateSelected : Maybe Time.Posix
  }

testModelInit : () -> (TestModel, Cmd Msg)
testModelInit () =
  ( { percentiles = Loading
    , userRatings = Nothing
    , mousePosition = Nothing
    , showMouse = False
    , dateSelected = Nothing
    }
  , Percentiles.fetch PerfType.default PercentilesResponse)

sizeAttributes : List (Attribute msg)
sizeAttributes =
  let
      svgHeight =
        margins.top + margins.bottom + chartDimensions.height

      svgWidth =
        margins.right + margins.left + chartDimensions.width
  in
      [ height ( Px svgHeight )
      , width ( Px svgWidth )
      , viewBox 0 0 svgWidth svgHeight
      ]

testView : TestModel -> Html Msg
testView model =
  let
      content =
        case model.percentiles of
          Success percentiles ->
            view (Model
              percentiles
              model.userRatings
              model.mousePosition
              model.showMouse
              model.dateSelected)
              StartSelectingDate
              StopSelectingDate
              ShowMouse
              HideMouse

          _ ->
            svg
              sizeAttributes
              [ g [ transform [Translate 30 30] ]
                [ TypedSvg.text_ [] [TypedSvg.Core.text "No model"]
                ]
              ]
  in
      content

testSubscriptions : TestModel -> Sub Msg
testSubscriptions model =
  Sub.none



main =
  Browser.element
    { init = testModelInit
    , update = testUpdate
    , view = testView
    , subscriptions = testSubscriptions
    }
