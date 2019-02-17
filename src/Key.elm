module Key exposing (Key, allKeys, fromString, toString)


type Key
    = C
    | Db
    | D
    | Eb
    | E
    | F
    | Gb
    | G
    | Ab
    | A
    | Bb
    | B


allKeys : List Key
allKeys =
    [ C, Db, D, Eb, E, F, Gb, G, Ab, A, Bb, B ]


toString : Key -> String
toString key =
    case key of
        C ->
            "C"

        Db ->
            "Db"

        D ->
            "D"

        Eb ->
            "Eb"

        E ->
            "E"

        F ->
            "F"

        Gb ->
            "Gb"

        G ->
            "G"

        Ab ->
            "Ab"

        A ->
            "A"

        Bb ->
            "Bb"

        B ->
            "B"


fromString : String -> Key
fromString s =
    case s of
        "C" ->
            C

        "Db" ->
            Db

        "D" ->
            D

        "E" ->
            E

        "F" ->
            F

        "Gb" ->
            Gb

        "G" ->
            G

        "Ab" ->
            Ab

        "A" ->
            A

        "Bb" ->
            Bb

        "B" ->
            B

        _ ->
            C
