module Model exposing (Service, Setlist, SetlistSong, Song, SongId, SpotifyAlbum, SpotifyAlbumImage, SpotifyArtist, SpotifyTrack, SpotifyTrackFeatures, SpotifyTrackId)


type alias Service =
    { id : String
    , dates : String
    , serviceTypeId : String
    }


type alias SpotifyAlbumImage =
    { height : Int
    , width : Int
    , url : String
    }


type alias SpotifyArtist =
    { name : String }


type alias SpotifyAlbum =
    { name : String
    , artists : List SpotifyArtist
    , images : List SpotifyAlbumImage
    }


type alias SpotifyTrackFeatures =
    { tempo : Float
    , key : Int
    }


type alias SpotifyTrackId =
    String


type alias SpotifyTrack =
    { id : SpotifyTrackId
    , name : String
    , href : String
    , album : SpotifyAlbum
    , features : SpotifyTrackFeatures
    }


type alias SongId =
    String


type alias Song =
    { id : SongId
    , title : String
    , key : String
    , spotifyMatches : List SpotifyTrack
    }


type alias SetlistSong =
    { id : SongId
    , title : String
    , key : String
    , tempo : Int
    }


type alias Setlist =
    { id : String
    , name : String
    , songs : List SetlistSong
    }
