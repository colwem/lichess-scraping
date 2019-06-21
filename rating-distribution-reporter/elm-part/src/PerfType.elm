module PerfType exposing (PerfType(..), toDisplay, toString, fromString
  , fromDisplay, decodeDisplay, perfTypes, default )

import Json.Decode as Decode exposing (Decoder)

type PerfType
  = Bullet
  | Blitz
  | Rapid
  | Classical
  | UltraBullet
  | Crazyhouse
  | Chess960
  | Atomic
  | KingOfTheHill
  | Horde
  | RacingKings
  | ThreeCheck
  | Antichess

default : PerfType
default = Blitz

toDisplay : PerfType -> String
toDisplay perfType =
  case perfType of
    Bullet -> "Bullet"
    Blitz -> "Blitz"
    Rapid -> "Rapid"
    Classical -> "Classical"
    UltraBullet -> "UltraBullet"
    Crazyhouse -> "Crazyhouse"
    Chess960 -> "Chess960"
    Atomic -> "Atomic"
    KingOfTheHill -> "King of the Hill"
    Horde -> "Horde"
    RacingKings -> "Racing Kings"
    ThreeCheck -> "Three-check"
    Antichess -> "Antichess"

toString : PerfType -> String
toString perfType =
  case perfType of
    Bullet -> "bullet"
    Blitz -> "blitz"
    Rapid -> "rapid"
    Classical -> "classical"
    UltraBullet -> "ultraBullet"
    Crazyhouse -> "crazyhouse"
    Chess960 -> "chess960"
    Atomic -> "atomic"
    KingOfTheHill -> "kingOfTheHill"
    Horde -> "horde"
    RacingKings -> "racingKings"
    ThreeCheck -> "threeCheck"
    Antichess -> "antichess"

fromString : String -> PerfType
fromString perfType =
  case perfType of
    "bullet" -> Bullet
    "blitz" -> Blitz
    "rapid" -> Rapid
    "classical" -> Classical
    "ultraBullet" -> UltraBullet
    "crazyhouse" -> Crazyhouse
    "chess960" -> Chess960
    "atomic" -> Atomic
    "kingOfTheHill" -> KingOfTheHill
    "horde" -> Horde
    "racingKings" -> RacingKings
    "threeCheck" -> ThreeCheck
    "antichess" -> Antichess
    _ -> default

fromDisplay : String -> PerfType
fromDisplay perfType =
  case perfType of
    "Bullet" -> Bullet
    "Blitz" -> Blitz
    "Rapid" -> Rapid
    "Classical" -> Classical
    "UltraBullet" -> UltraBullet
    "Crazyhouse" -> Crazyhouse
    "Chess960" -> Chess960
    "Atomic" -> Atomic
    "King of the Hill" -> KingOfTheHill
    "Horde" -> Horde
    "Racing Kings" -> RacingKings
    "Three-check" -> ThreeCheck
    "Antichess" -> Antichess
    _ -> default

perfTypes : List PerfType
perfTypes =
  [ Bullet
  , Blitz
  , Rapid
  , Classical
  , UltraBullet
  , Crazyhouse
  , Chess960
  , Atomic
  , KingOfTheHill
  , Horde
  , RacingKings
  , ThreeCheck
  , Antichess
  ]

decodeDisplay : Decoder PerfType
decodeDisplay =
  Decode.map (fromDisplay) Decode.string

decode : Decoder PerfType
decode =
  Decode.map (fromString) Decode.string
