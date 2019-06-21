module Chart exposing (horizontalLineAttributes, verticalLineAttributes)

import TypedSvg.Types exposing (Length(..))
import TypedSvg.Attributes exposing (x1, x2, y1, y2)
import TypedSvg.Core exposing (Attribute)

horizontalLineAttributes : Float -> (Float, Float) -> List (Attribute msg)
horizontalLineAttributes y (left, right)=
  [ x1 ( Px left )
  , x2 ( Px right )
  , y1 ( Px y )
  , y2 ( Px y )
  ]

verticalLineAttributes : Float -> (Float, Float) -> List (Attribute msg)
verticalLineAttributes  x (top, bottom) =
  [ x1 ( Px x )
  , x2 ( Px x )
  , y1 ( Px top )
  , y2 ( Px bottom )
  ]
