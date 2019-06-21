module Point exposing (Point, TimePoint, diff)

import Time

type alias Point =
  { x : Float
  , y : Float
  }

type alias TimePoint =
  { x : Time.Posix
  , y : Float
  }

diff : Point -> Point -> Point
diff a b =
  Point (a.x - b.x) (a.y - b.y)
