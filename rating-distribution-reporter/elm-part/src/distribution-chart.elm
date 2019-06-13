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
import Shape
import Statistics

-- typed-svg
import TypedSvg exposing (g, svg)
import TypedSvg exposing (svg, circle, rect, text_)
import TypedSvg.Attributes exposing
  (viewBox, cx, cy, r, fill, strokeWidth, stroke, height, width
  , class, transform, fillOpacity, x1, x2, y1, y2, strokeDasharray)
import TypedSvg.Attributes.InPx exposing (strokeWidth)
import TypedSvg.Core exposing (Svg, Attribute)
import TypedSvg.Types exposing (Fill(..), Transform(..), Length(..), Opacity(..))
import TypedSvg.Events
import VirtualDom

-- Css
import Css
import Html.Styled
import Css.Global as Css
import Svg.Styled.Attributes as SvgCss


chartDimensions : { width : Float, height : Float }
chartDimensions =
  { width = 800
  , height = 300}

margins : { top : Float, bottom : Float, right : Float, left : Float }
margins =
  { top = 50
  , bottom = 50
  , right = 50
  , left = 50
  }


curve : List ( Float, Float ) -> SubPath
curve =
  Shape.linearCurve

cumulativeLineColor = Color.yellow
numPlayersLineColor = Color.rgb255 127 158 195

-- Mouse stuff

type alias Point =
    ( Float, Float )

pointX = Tuple.first
pointY = Tuple.second

pointDiff: Point -> Point -> Point
pointDiff a b =
  ((pointX a) - (pointX b), (pointY a) - (pointY b))

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

mousePositionDecoder : Decoder Point
mousePositionDecoder =
  Decode.map2 Tuple.pair
    (Decode.field "clientX" Decode.float)
    (Decode.field "clientY" Decode.float)

onMouseMove : (Point -> a) -> Attribute a
onMouseMove msgConstructor =
  TypedSvg.Events.on "mousemove"
    <| VirtualDom.Normal
    <| Decode.map msgConstructor mousePositionDecoder

-- Model

type alias Distribution = List Float
type alias Model =
  { distribution : Distribution
  , mouseShow : Bool
  , mousePosition : Maybe Point
  }

testModel : Model
testModel =
  { mousePosition = Nothing
  , mouseShow = False
  , distribution = [2701,1653,1877,2102,2567,2918,3324,3813,4156,4554,4760,5109,5278,5654,5749
    ,6098,6347,6349,6265,6232,6503,6562,6582,6290,6610,6604,6408,6322,6669,6488
    ,6348,6002,6095,5750,5540,5065,5442,4869,4723,4341,4599,4006,3667,3271,3447
    ,2889,2551,2307,2583,2027,1814,1420,1439,1199,992,765,868,627,540,377,431
    ,296,230,190,177,146,104,68,92,57,42,25,17,8,12,11,13,1,3,2,2]
  }

type alias CumulativeModel = List Float

getCumulativeModel : Distribution -> CumulativeModel
getCumulativeModel =
  List.drop 1
    << List.scanl (\a b -> a + b) 0

-- update

type Msg
  = MouseMove Point
  | MouseRelative (Result Browser.Dom.Error Point)
  | MouseLeave
  | MouseEnter

testUpdate : Msg -> Model -> (Model, Cmd Msg)
testUpdate msg model =
  case msg of
    MouseMove point ->
      let
          x = Tuple.first point
          y = Tuple.second point
      in
          ( model
          , Browser.Dom.getElement "overlay"
            |> Task.map (\e -> (x - e.element.x , y - e.element.y) )
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

    MouseLeave ->
      ({ model | mouseShow = False }
      , Cmd.none
      )

    MouseEnter ->
      ({ model | mouseShow = True }
      , Cmd.none
      )


-- Scales

getXScale : Distribution -> ContinuousScale Float
getXScale model =
  let
      domain = (0, List.length model - 1 |> toFloat)
      range = (0, chartDimensions.width)
  in
      Scale.linear range domain

getYScale : Distribution -> ContinuousScale Float
getYScale model =
  let
      domain =
        ( 0
        , Statistics.extent model
          |> Maybe.withDefault (0, 0)
          |> Tuple.second
        )
      range = (chartDimensions.height, 0)

  in
      Scale.linear range domain

ratingScale : ContinuousScale Float
ratingScale =
  Scale.linear (0, chartDimensions.width) (800, 2800)


getCumulativeScale : CumulativeModel -> ContinuousScale Float
getCumulativeScale model =
  Statistics.extent model
    |> Maybe.withDefault (0, 0)
    |> Scale.linear (chartDimensions.height, 0)


-- Shape generators

getPairs : Distribution -> List (Float, Float)
getPairs = List.indexedMap (\x y -> (toFloat x, y))

area : ContinuousScale Float -> ContinuousScale Float -> Distribution -> Path
area xScale yScale model =
  let
      pairToAreaCoords (x, y) =
        Just
          (
            ( Scale.convert xScale x
            , Tuple.first (Scale.rangeExtent yScale)
            ),
            ( Scale.convert xScale x
            , Scale.convert yScale y
            )
          )
  in
      getPairs model
        |> List.map pairToAreaCoords
        |> Shape.area curve

line xScale yScale model =
  let
      lineData (x, y) =
        Just ( Scale.convert xScale x, Scale.convert yScale y)
  in
      List.map lineData (getPairs model)
        |> Shape.line curve

-- Axes

viewRatingAxis : ContinuousScale Float -> Svg msg
viewRatingAxis scale =
  g [ transform [Translate 0 chartDimensions.height]]
    [ Axis.bottom [Axis.tickCount 20] scale ]

viewNumPlayersAxis : ContinuousScale Float -> Svg msg
viewNumPlayersAxis scale =
  let
      formatter n =
        String.fromInt (round ( n / 1000 ) ) ++ "k"
  in
      g [ transform [Translate 0 0]]
        [ Axis.left
            [ Axis.tickCount 6
            , Axis.tickFormat formatter
            , Axis.tickSizeInner 0
            , Axis.tickSizeOuter 0
            , Axis.tickPadding 10
            ]
            scale
        ]

viewCumulativeAxis : Svg msg
viewCumulativeAxis =
  let
      percentFormatter n =
        String.fromInt ( round ( n * 100 ) ) ++ "%"
      scale = Scale.linear (chartDimensions.height, 0) (0, 1)
  in
      g [ transform [Translate chartDimensions.width 0]]
        [ Axis.right
            [ Axis.tickCount 4
            , Axis.tickFormat percentFormatter
            , Axis.tickSizeInner 0
            , Axis.tickSizeOuter 0
            , Axis.tickPadding 10
            ]
            scale
        ]

-- grid

viewYGrid : ContinuousScale Float -> Svg msg
viewYGrid scale =
  g [ transform [Translate 0 0]]
    [ Axis.left
      [ Axis.tickCount 6
      , Axis.tickFormat <| always ""
      , Axis.tickSizeInner <| negate chartDimensions.width
      , Axis.tickSizeOuter 0
      ]
      scale
    ]

viewXGrid : ContinuousScale Float -> Svg msg
viewXGrid scale =
  g [ transform [Translate 0 (chartDimensions.height)]]
    [ Axis.bottom
        [ Axis.tickCount 20
        , Axis.tickFormat <| always ""
        , Axis.tickSizeInner <| negate chartDimensions.height
        , Axis.tickSizeOuter 0
        ]
        scale
    ]

-- views

createGChart : List (Svg msg) -> Svg msg
createGChart =
  g [ transform [Translate margins.left margins.top ] ]

viewNumPlayersLine : ContinuousScale Float -> ContinuousScale Float ->
 Distribution -> Svg msg
viewNumPlayersLine xScale yScale model =
  Path.element (line xScale yScale model)
    [ stroke numPlayersLineColor
    , strokeWidth 3
    , fill FillNone
    ]

viewCumulativeLine : ContinuousScale Float -> ContinuousScale Float ->
 Distribution -> Svg msg
viewCumulativeLine xScale yScale model =
  Path.element (line xScale yScale model)
    [ stroke cumulativeLineColor
    , strokeWidth 3
    , fill FillNone
    ]


viewNumPlayersArea : ContinuousScale Float -> ContinuousScale Float ->
 Distribution -> Svg msg
viewNumPlayersArea xScale yScale model =
  Path.element  (area xScale yScale model)
    [ strokeWidth 3
    , fill <| Fill <| fadeOut 0.2 numPlayersLineColor
    ]


-- Mouse tracking lines

viewMouseOverlay : Svg Msg
viewMouseOverlay =
  rect
    [ id "overlay"
    , height <| Px chartDimensions.height
    , width <| Px chartDimensions.width
    , fillOpacity <| Opacity 0
    , onMouseMove MouseMove
    , TypedSvg.Events.onMouseOver MouseEnter
    , TypedSvg.Events.onMouseLeave MouseLeave
    ] []

viewMouseLines : Point -> List (Svg Msg)
viewMouseLines point =
  let
      x = Tuple.first point
      y = Tuple.second point

      commonAttr =
        [ strokeDasharray "3,3"
        , stroke <| fadeOut 0.3 Color.black]

      xline =
        TypedSvg.line
          ([ x1 <| Px  x
          , x2 <| Px  x
          , y1 <| Px 0
          , y2 <| Px chartDimensions.height
          ] ++ commonAttr) []

      yline =
        TypedSvg.line
          ([ x1 <| Px 0
          , x2 <| Px chartDimensions.width
          , y1 <| Px y
          , y2 <| Px y
          ] ++ commonAttr) []
  in
      [ xline
      , yline ]

-- View

pointToString : Point -> String
pointToString point =
  let
      x = Tuple.first point |> String.fromFloat
      y = Tuple.second point |> String.fromFloat
  in
      "(" ++ x ++ ", " ++ y ++ ")"

view : Model -> Html Msg
view model =
  let
      xScale = getXScale model.distribution
      yScale = getYScale model.distribution
      cumulativeModel = getCumulativeModel model.distribution
      cumulativeScale = getCumulativeScale cumulativeModel
      mouseLines =
        if model.mouseShow then
          case model.mousePosition of
            Nothing ->
              []
              -- [text_ [] [text "Nothing"]]
            Just point ->
              -- [text_ [] [text (pointToString point)]] ++
              viewMouseLines point
        else []
  in
      createGChart <|
        [ viewRatingAxis ratingScale
        , viewNumPlayersAxis yScale
        , viewCumulativeAxis
        , viewXGrid ratingScale
        , viewYGrid yScale
        , viewNumPlayersArea xScale yScale model.distribution
        , viewNumPlayersLine xScale yScale model.distribution
        , viewCumulativeLine xScale cumulativeScale cumulativeModel]
        ++ mouseLines
        ++ [viewMouseOverlay]


sizeAttributes : List (Attribute msg)
sizeAttributes =
  let
      svgHeight =
        margins.top + margins.bottom + chartDimensions.height

      svgWidth =
        margins.right + margins.left + chartDimensions.width
  in
      [ height <| Px svgHeight
      , width <| Px svgWidth
      , viewBox 0 0 svgWidth svgHeight
      ]


testView : Model -> Html Msg
testView model =
  svg
    sizeAttributes
    [view model]

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none

init () =
  (testModel, Cmd.none)

main =
  Browser.element
    { init = init
    , update = testUpdate
    , view = testView
    , subscriptions = subscriptions
    }
