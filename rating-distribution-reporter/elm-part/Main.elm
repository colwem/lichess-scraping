-- Main.elm
module Main exposing (main)

import Browser
import Html exposing (h1, text)

init () =
  ( 1
  , Cmd.none
  )

update model msg =
  ( 1
  , Cmd.none)

view model =
  h1 [] [ text "Hello, canada!" ]

subscriptions model =
  Sub.none

main =
  Browser.element
    { init = init
    , update = update
    , view = view
    , subscriptions = subscriptions
    }
