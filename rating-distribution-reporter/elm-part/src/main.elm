import Http
import Time
import Json.Decode as D
import UserRatingHistory


type alias Model =
  { usernameInput : String
  , username : Maybe Username
  , userRatingHistory : Loaded UserRatingHistory
  , fetchingUserRatingHistory : Bool
  , percentiles : Loaded Percentiles
  , distributions : Loaded (List DatedDistribution)
  , dateSelected : Time.Posix
  , perfTypeSelected : PerfType
  , globalMousePosition : MousePosition
  , distributionChartModel : DistributionChartModel
  , percentilesChartModel : PercentilesChartModel
  }

type Loaded a
  = Loading
  | Success a
  | Failure LoadingProblem

type Username = Username String


type Percentiles
  = Percentiles (list Percentile)

type Percentile
  = Percentile
    { percentile : Float
    , data : {date: Time.Posix, rating : Float}
    }

type alias DatedDistribution =
  { date : Time.Posix
  , distribution : Distribution
  }

type Distribution
  = Distribution (List Int)

type LoadingProblem
  = String

type MousePosition
  = UnknownMousePosition
  | MousePosition Point

type alias Point =
  { x : Float
  , y : Float
  }

type DistributionChartModel
  = DistributionChartModel
    { distribution : Distribution
    , relativeMousePosition : MousePosition
    , userRating : Rating
    }

type PercentilesChartModel
  = PercentilesChartModel
    { percentiles : Percentiles
    , relativeMousePosition : MousePosition
    , userRatingHistory : UserRatingHistory
    }

dataModelDecoder : Decoder DataModel
dataModelDecoder =
  D.list datedDistributionDecoder

datedDistributionDecoder : Decoder DatedDistribution
datedDistributionDecoder =
  D.map2 DatedDistribution
    ( D.field "date" ( D.map Time.millisToPosix D.int ) )
    ( D.field "distribution" distributionDecoder )

distributionDecoder : Decoder Distribution
distributionDecoder =
  D.list D.int


init : () -> (Model, Cmd Msg)
init _ =
  let
      perfType = "Blitz"
  in
  ( {username = Nothing
    , dataset = Nothing
    , distribution = Nothing
    , perType = "Blitz"
    , mousePosition = UnknownMousePosition
    }
  , getDataset perfType)

type Msg
  = ChangeDataset String
  | MouseMove MousePosition
  | GotDataset (Result Http.Error Dataset)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    ChangeDataset perfType ->
      ({ model | perfType = perfType }
      , Http.get
          { url = api.distributions ++ perfType
          , expect = Http.expectJson GotDataset dataModelDecoder
          })

    MouseMove mousePosition ->
      { model | mousePosition = mousePosition }

    GotDataset result ->
      case result of
        Err _ ->
          { model | dataset = Failure }

        Ok dataModel ->
          let
              date = getValidDate model.date dataset
              distribution = getDistribution model.date dataset
          in
              { model | dataset = Success dataset
              , distribution = distribution,
              , date = date
              }


getDistribution : DataModel -> Time.Posix -> Distribution
getDistribution dataModel date =
  let
      defaultDistribution = [0]
  in
  List.find (\x -> x.date == date) dataModel
    |> Maybe.withDefault defaultDistribution

getValidDate : Time.Posix -> DataModel -> Time.Posix
getValidDate date dataModel =
  let
      dataModelToDateList dm =
        List.map ( \x -> x.date ) dm
  in
      getClosest identity model.date (dataModelToDateList dataModel)

view = Model -> Html Msg
view model =
  div []
    [ H.h1 [] [ text "Distributions" ]
    , viewPerfTypeSelector model.perfType model.perfTypes
    , dateSelector (availableDates model.dataset) model.date
    , viewChart model.distribution model.mousePosition
    ]

viewPerfTypeSelector : List String -> Html Msg
viewPerfTypeSelector perfType perfTypes =
  H.select []
  [ List.map ( viewPerfTypeOption perfType ) perfTypes]

viewPerfTypeOption : String -> String -> Html Msg
viewPerfTypeOption current perfType =
  let
      attributes =
        if current == perfType
        then [ A.selected ]
        else []
  in
      H.option attributes [ text perfType ]

getClosest : ( a -> comparable ) -> comparable -> List a -> Maybe a
getClosest accessor target list =
  List.minimumBy (\x -> accessor x - target |> abs) list

-- getClosest accessor target list =
  -- let
      -- distance a b = abs ( a - b )

      -- next current x =
        -- let
            -- d = accessor x |> distance target
        -- in
            -- if  d < Tuple.first current
            -- then (d, x)
            -- else current

      -- first = head list
      -- start = (distance first target, first)
  -- in
      -- case list of
        -- [] ->
          -- Nothing

        -- x :: [] ->
          -- Just x

        -- _ ->
          -- Just (foldl next first list |> Tuple.second)
