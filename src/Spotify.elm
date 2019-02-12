module Spotify exposing (key)


key : Int -> String
key x =
    case x of
        0 ->
            "C"

        1 ->
            "Db"

        2 ->
            "D"

        3 ->
            "Eb"

        4 ->
            "E"

        5 ->
            "F"

        6 ->
            "Gb"

        7 ->
            "G"

        8 ->
            "Ab"

        9 ->
            "A"

        10 ->
            "Bb"

        11 ->
            "B"

        _ ->
            ""
