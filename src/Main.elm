port module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Debouncer.Messages as Debouncer exposing (Debouncer, fromSeconds, provideInput, settleWhenQuietFor, toDebouncer)
import Dict exposing (Dict)
import GraphQL.Client.Http as GraphQLClient
import GraphQL.Request.Builder exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import Html.Keyed
import Json.Encode
import Key exposing (Key, allKeys)
import Model exposing (..)
import Queries exposing (addSongToSetlistMutation, createSetlistMutation, removeSetlistMutation, removeSongFromSetlistMutation, runMutation, runQuery, serviceSongsQuery, servicesQuery, setlistsQuery, spotifyTracksQuery, updateSongMutation)
import Spotify exposing (key)
import Task exposing (Task)
import Url
import Url.Parser exposing ((</>), Parser, int, map, oneOf, s, top)


getServices =
    runQuery servicesQuery [] ServicesReceived


getServiceSongs : { serviceId : String, serviceTypeId : String } -> Cmd Msg
getServiceSongs args =
    runQuery serviceSongsQuery args (ServiceSongsReceived args.serviceId)


getSetlists =
    runQuery setlistsQuery [] SetlistsReceived


getSpotifyTracks : { title : String } -> Cmd Msg
getSpotifyTracks args =
    runQuery spotifyTracksQuery args SpotifyTracksReceived


createSetlist args =
    runMutation createSetlistMutation args SetlistCreated


removeSetlist args =
    runMutation removeSetlistMutation args (SetlistRemoved args.setlistId)


addSongToSetlist : { setlistId : SetlistId, key : String, title : String, tempo : Int } -> Cmd Msg
addSongToSetlist args =
    runMutation addSongToSetlistMutation args (SongAddedToSetlist args.setlistId)


removeSongFromSetlist args =
    runMutation removeSongFromSetlistMutation args (SongRemovedFromSetlist args.setlistId args.songId)


updateSong args =
    runMutation updateSongMutation args (SongUpdated args.setlistId args.songId)


h1 attrs children =
    Html.h1 (List.concat [ attrs, [ class "ui header" ] ]) children


type alias SetupSongsPacket =
    { basePreset : Int
    , startingPreset : Int
    , songs :
        List
            { key : String
            , title : String
            , tempo : Int
            }
    }


port setupSongs : SetupSongsPacket -> Cmd msg


port midiReceived : (Json.Encode.Value -> msg) -> Sub msg


makeSetupSongsPacket : Int -> Int -> List ( Song, Maybe SpotifyTrack ) -> SetupSongsPacket
makeSetupSongsPacket basePreset startingPreset songs =
    { basePreset = basePreset
    , startingPreset = startingPreset
    , songs =
        List.map
            (\( song, track ) ->
                { key = song.key
                , title = song.title
                , tempo =
                    case track of
                        Just t ->
                            round t.features.tempo

                        Nothing ->
                            0
                }
            )
            songs
    }


pairSongTrack : Model -> Song -> ( Song, Maybe SpotifyTrack )
pairSongTrack model song =
    ( song, getSelectedTrack model song )


packSongs : Model -> Maybe SetupSongsPacket
packSongs model =
    let
        songs : Maybe (List Song)
        songs =
            case model.route of
                Just (ServiceDetail serviceTypeId serviceId) ->
                    Dict.get serviceId model.songsByServiceId

                _ ->
                    Nothing
    in
    Maybe.map (List.map (pairSongTrack model)) songs
        |> Maybe.map (makeSetupSongsPacket model.basePreset model.startingPreset)


main =
    Browser.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


type Msg
    = ServicesReceived (Result GraphQLClient.Error (List Service))
    | ServiceSongsReceived String (Result GraphQLClient.Error (List Song))
    | SetlistsReceived (Result GraphQLClient.Error (List Setlist))
    | SpotifyTracksReceived (Result GraphQLClient.Error (List SpotifyTrack))
    | SongQueryChanged String (Debouncer.Msg Msg)
    | MsgWaitForOneSecond (Debouncer.Msg Msg)
    | SongQueryChangedOneSecondAgo
    | AddSpotifyTrackToSetlist SetlistId SpotifyTrack
    | ExpandTrackMatches SongId
    | SelectTrackForSong Song SpotifyTrack
    | SendToDevice
    | BasePresetChanged String
    | StartingPresetChanged String
    | SetlistCreateSubmit
    | SetlistCreated (Result GraphQLClient.Error { id : String })
    | SongAddedToSetlist SetlistId (Result GraphQLClient.Error SetlistSong)
    | NewSetlistNameChanged String
    | UrlChanged Url.Url
    | LinkClicked Browser.UrlRequest
    | RemoveSetlist SetlistId
    | SetlistRemoved SetlistId (Result GraphQLClient.Error Bool)
    | RemoveSongFromSetlist SetlistId SongId
    | SongRemovedFromSetlist SetlistId SongId (Result GraphQLClient.Error Bool)
    | UpdateSongKey SetlistId SongId Key
    | SongUpdated SetlistId SongId (Result GraphQLClient.Error SetlistSong)
    | UpdateSongTempo SetlistId SongId String


type alias Model =
    { key : Nav.Key
    , route : Maybe Route
    , loggedIn : Bool
    , loadingServices : Bool
    , loadingServiceDetail : Bool
    , loadingSetlists : Bool
    , servicesById : Dict String Service
    , songsByServiceId : Dict String (List Song)
    , selectedTrackIdBySongId : Dict SongId SpotifyTrackId
    , expandedBySongId : Dict SongId Bool
    , basePreset : Int
    , startingPreset : Int
    , newSetlistName : String
    , spotifyTracks : List SpotifyTrack
    , songQuery : String
    , waitForOneSecond : Debouncer Msg
    , creatingSetlist : Bool
    , setlistsById : Dict String Setlist
    , creatingSetlistFailed : Bool
    }


type alias Flags =
    { loggedIn : Bool }


waitForOneSecond =
    Debouncer.debounce (fromSeconds 1)
        |> toDebouncer


updateDebouncer : Debouncer.UpdateConfig Msg Model
updateDebouncer =
    { mapMsg = MsgWaitForOneSecond
    , getDebouncer = .waitForOneSecond
    , setDebouncer = \debouncer model -> { model | waitForOneSecond = debouncer }
    }


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        route =
            Url.Parser.parse routeParser url
    in
    ( case route of
        Just ServicesList ->
            Model key route flags.loggedIn True False False Dict.empty Dict.empty Dict.empty Dict.empty 1 2 "" [] "" waitForOneSecond False Dict.empty False

        Just (ServiceDetail _ _) ->
            Model key route flags.loggedIn True True False Dict.empty Dict.empty Dict.empty Dict.empty 1 2 "" [] "" waitForOneSecond False Dict.empty False

        Just SetlistsList ->
            Model key route flags.loggedIn False False True Dict.empty Dict.empty Dict.empty Dict.empty 1 2 "" [] "" waitForOneSecond False Dict.empty False

        Just (SetlistDetail _) ->
            Model key route flags.loggedIn False False True Dict.empty Dict.empty Dict.empty Dict.empty 1 2 "" [] "" waitForOneSecond False Dict.empty False

        _ ->
            Model key route flags.loggedIn False False False Dict.empty Dict.empty Dict.empty Dict.empty 1 2 "" [] "" waitForOneSecond False Dict.empty False
    , if flags.loggedIn then
        case route of
            Just ServicesList ->
                getServices

            Just (ServiceDetail serviceTypeId serviceId) ->
                Cmd.batch [ getServices, getServiceSongs { serviceId = serviceId, serviceTypeId = serviceTypeId } ]

            Just SetlistsList ->
                getSetlists

            Just (SetlistDetail _) ->
                getSetlists

            _ ->
                Cmd.none

      else
        Cmd.none
    )


type alias ServiceId =
    String


type alias ServiceTypeId =
    String


type alias SetlistId =
    String


type Route
    = ServicesList
    | ServiceDetail ServiceTypeId ServiceId
    | SetlistsList
    | SetlistDetail SetlistId
    | SetlistCreate


routeParser : Parser (Route -> a) a
routeParser =
    oneOf
        [ map SetlistsList top
        , map SetlistsList (s "setlists")
        , map SetlistCreate (s "setlists" </> s "new")
        , map SetlistDetail (s "setlists" </> Url.Parser.string)
        , map ServicesList (s "services")
        , map ServiceDetail (s "services" </> s "types" </> Url.Parser.string </> s "service" </> Url.Parser.string)
        ]


updateSongKey : SongId -> Key -> SetlistSong -> SetlistSong
updateSongKey songId key song =
    if song.id == songId then
        { song | key = Key.toString key }

    else
        song


updateSongTempo : SongId -> Int -> SetlistSong -> SetlistSong
updateSongTempo songId tempo song =
    if song.id == songId then
        { song | tempo = tempo }

    else
        song


updateSongAttributes : SongId -> SetlistSong -> SetlistSong -> SetlistSong
updateSongAttributes songId newSong song =
    if song.id == songId then
        newSong

    else
        song


log : a -> a
log a =
    let
        s =
            Debug.log (Debug.toString a)
    in
    a


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateSongTempo setlistId songId tempoString ->
            case String.toInt tempoString of
                Just tempo ->
                    case Dict.get setlistId model.setlistsById of
                        Just setlist ->
                            let
                                songs =
                                    List.map (updateSongTempo songId tempo) setlist.songs

                                newSetlist =
                                    { setlist | songs = songs }
                            in
                            ( { model | setlistsById = Dict.insert setlistId newSetlist model.setlistsById }
                            , updateSong
                                { setlistId = setlistId
                                , songId = songId
                                , tempo = Just <| Just tempo
                                , key = Nothing
                                , title = Nothing
                                }
                            )

                        Nothing ->
                            ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        UpdateSongKey setlistId songId key ->
            case Dict.get setlistId model.setlistsById of
                Just setlist ->
                    let
                        songs =
                            List.map (updateSongKey songId key) setlist.songs

                        newSetlist =
                            { setlist | songs = songs }
                    in
                    ( { model | setlistsById = Dict.insert setlistId newSetlist model.setlistsById }, updateSong { setlistId = setlistId, songId = songId, key = Just <| Just <| Key.toString key, title = Nothing, tempo = Nothing } )

                Nothing ->
                    ( model, Cmd.none )

        SongUpdated setlistId songId (Ok song) ->
            case Dict.get setlistId model.setlistsById of
                Just setlist ->
                    let
                        songs =
                            List.map (updateSongAttributes songId song) setlist.songs

                        newSetlist =
                            { setlist | songs = songs }
                    in
                    ( { model | setlistsById = Dict.insert setlistId newSetlist model.setlistsById }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        SongUpdated _ _ _ ->
            ( model, Cmd.none )

        SongRemovedFromSetlist setlistId songId (Ok True) ->
            let
                setlist =
                    case Dict.get setlistId model.setlistsById of
                        Just s ->
                            { s | songs = List.filter (\song -> song.id /= songId) s.songs }

                        Nothing ->
                            { id = "null-list"
                            , songs = []
                            , name = "Null List"
                            }
            in
            case Dict.get setlistId model.setlistsById of
                Just s ->
                    ( { model | setlistsById = Dict.insert setlistId setlist model.setlistsById }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        SongRemovedFromSetlist _ _ _ ->
            ( model, Cmd.none )

        RemoveSongFromSetlist setlistId songId ->
            ( model, removeSongFromSetlist { setlistId = setlistId, songId = songId } )

        SetlistRemoved setlistId (Ok True) ->
            ( { model | setlistsById = Dict.remove setlistId model.setlistsById }, Cmd.none )

        SetlistRemoved _ _ ->
            ( model, Cmd.none )

        RemoveSetlist setlistId ->
            ( model, removeSetlist { setlistId = setlistId } )

        NewSetlistNameChanged name ->
            ( { model | newSetlistName = name }, Cmd.none )

        SetlistCreateSubmit ->
            ( { model | creatingSetlist = True }, createSetlist { name = model.newSetlistName } )

        SetlistCreated (Ok { id }) ->
            ( { model | setlistsById = Dict.insert id { id = id, name = model.newSetlistName, songs = [] } model.setlistsById }, Nav.pushUrl model.key <| "/setlists/" ++ id )

        SetlistCreated (Err _) ->
            ( { model | creatingSetlistFailed = True }, Cmd.none )

        AddSpotifyTrackToSetlist setlistId spotifyTrack ->
            ( { model | spotifyTracks = [], songQuery = "" }
            , addSongToSetlist
                { setlistId = setlistId
                , title = spotifyTrack.name
                , key = key spotifyTrack.features.key
                , tempo = round spotifyTrack.features.tempo
                }
            )

        SongAddedToSetlist setlistId (Ok song) ->
            let
                setlist =
                    case Dict.get setlistId model.setlistsById of
                        Just s ->
                            { s | songs = s.songs ++ [ song ] }

                        Nothing ->
                            { id = "null-list"
                            , songs = []
                            , name = "Null List"
                            }
            in
            case Dict.get setlistId model.setlistsById of
                Just s ->
                    ( { model | setlistsById = Dict.insert setlistId setlist model.setlistsById }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        SongAddedToSetlist _ (Err _) ->
            ( model, Cmd.none )

        MsgWaitForOneSecond subMsg ->
            Debouncer.update update updateDebouncer subMsg model

        SongQueryChanged query subMsg ->
            Debouncer.update update updateDebouncer subMsg { model | songQuery = query }

        SongQueryChangedOneSecondAgo ->
            ( model, getSpotifyTracks { title = model.songQuery } )

        SetlistsReceived (Ok setlists) ->
            ( { model | setlistsById = Dict.fromList <| List.map (\setlist -> ( setlist.id, setlist )) setlists, loadingSetlists = False }, Cmd.none )

        SetlistsReceived (Err _) ->
            ( model, Cmd.none )

        ServicesReceived (Ok services) ->
            ( { model
                | servicesById = Dict.fromList <| List.map (\service -> ( service.id, service )) services
                , loadingServices = False
              }
            , Cmd.none
            )

        ServicesReceived (Err _) ->
            ( model, Cmd.none )

        ServiceSongsReceived serviceId (Ok songs) ->
            ( { model
                | loadingServiceDetail = False
                , songsByServiceId = Dict.insert serviceId songs model.songsByServiceId
              }
            , Cmd.none
            )

        ServiceSongsReceived serviceId (Err _) ->
            ( model, Cmd.none )

        SpotifyTracksReceived (Ok tracks) ->
            ( { model | spotifyTracks = tracks }, Cmd.none )

        SpotifyTracksReceived (Err _) ->
            ( model, Cmd.none )

        ExpandTrackMatches songId ->
            ( { model
                | expandedBySongId = Dict.insert songId True model.expandedBySongId
              }
            , Cmd.none
            )

        SelectTrackForSong song track ->
            ( { model
                | selectedTrackIdBySongId = Dict.insert song.id track.id model.selectedTrackIdBySongId
                , expandedBySongId = Dict.remove song.id model.expandedBySongId
              }
            , Cmd.none
            )

        SendToDevice ->
            ( model
            , case packSongs model of
                Just packet ->
                    setupSongs packet

                _ ->
                    Cmd.none
            )

        BasePresetChanged value ->
            case String.toInt value of
                Just p ->
                    ( { model | basePreset = p }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        StartingPresetChanged value ->
            case String.toInt value of
                Just p ->
                    ( { model | startingPreset = p }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        LinkClicked (Browser.Internal url) ->
            ( model
            , if String.contains "/auth" <| Url.toString url then
                Nav.load <| Url.toString url

              else
                Nav.pushUrl model.key (Url.toString url)
            )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            let
                route =
                    Url.Parser.parse routeParser url
            in
            ( { model | route = route }
            , case route of
                Just ServicesList ->
                    getServices

                Just (ServiceDetail _ serviceId) ->
                    case Dict.get serviceId model.servicesById of
                        Just service ->
                            getServiceSongs
                                { serviceId = service.id
                                , serviceTypeId = service.serviceTypeId
                                }

                        _ ->
                            Cmd.none

                _ ->
                    Cmd.none
            )


subscriptions _ =
    Sub.none


serviceListItem : Service -> ( String, Html Msg )
serviceListItem service =
    ( service.id, li [] [ a [ href ("/services/types/" ++ service.serviceTypeId ++ "/service/" ++ service.id) ] [ text service.dates ] ] )


servicesList : Model -> Html Msg
servicesList model =
    let
        services =
            Dict.values model.servicesById
    in
    div []
        [ h1 [] [ text "Services" ]
        , text <| (String.fromInt <| List.length services) ++ " services"
        , Html.Keyed.ul [] <| List.map serviceListItem services
        ]


radiogroup : List (Attribute msg) -> List (Html msg) -> Html msg
radiogroup =
    node "radiogroup"



-- spotifyTrackListItem : Bool -> SpotifyTrack -> Html Msg


trackImageUrl : SpotifyTrack -> String
trackImageUrl track =
    case List.head <| List.filter (\i -> i.width == 64) track.album.images of
        Just image ->
            image.url

        Nothing ->
            "/images/compact-disc-1.svg"


spotifyTrackListItem isSelected onSelectTrack track =
    li []
        [ label
            [ onClick onSelectTrack ]
            [ input
                [ type_ "radio"
                , value track.id
                , checked isSelected
                , onClick onSelectTrack
                ]
                []
            , div
                [ style "display" "flex"
                , style "flexDirection" "row"
                ]
                [ img [ src <| trackImageUrl track ] []
                , div
                    [ style "display" "flex"
                    , style "flexDirection" "column"
                    ]
                    [ span [] [ text track.name ]
                    , span [] [ text track.album.name ]
                    , span []
                        [ List.map .name track.album.artists
                            |> String.join ", "
                            |> text
                        ]
                    ]
                ]
            ]
        ]


getSelectedTrack : Model -> Song -> Maybe SpotifyTrack
getSelectedTrack model song =
    case Dict.get song.id model.selectedTrackIdBySongId of
        Just trackId ->
            List.head <| List.filter (\t -> t.id == trackId) song.spotifyMatches

        Nothing ->
            List.head song.spotifyMatches


songListItem : Model -> Song -> ( String, Html Msg )
songListItem model song =
    let
        selectedTrack =
            getSelectedTrack model song

        selectedTrackImageUrl : String
        selectedTrackImageUrl =
            case selectedTrack of
                Just track ->
                    case List.head <| List.filter (\i -> i.width == 64) track.album.images of
                        Just image ->
                            image.url

                        Nothing ->
                            "/images/compact-disc-1.svg"

                Nothing ->
                    "/images/compact-disc-1.svg"

        expanded =
            case Dict.get song.id model.expandedBySongId of
                Just v ->
                    v

                Nothing ->
                    False
    in
    ( song.id
    , li
        [ style "display" "flex"
        , style "flexDirection" "column"
        ]
        [ div [ style "display" "flex", style "flexDirection" "row" ]
            [ img
                [ src selectedTrackImageUrl
                , style "width" "64px"
                , style "height" "64px"
                ]
                []
            , div
                [ style "display" "flex"
                , style "flexDirection" "column"
                , style "flex" "auto"
                ]
              <|
                List.concat
                    [ [ div [] [ text <| "[" ++ song.key ++ "] " ++ song.title ] ]
                    , case selectedTrack of
                        Just spotifyTrack ->
                            [ div [] [ text spotifyTrack.album.name ]
                            , div [] [ text <| String.fromInt (round spotifyTrack.features.tempo) ++ " bpm" ]
                            ]

                        Nothing ->
                            [ text "No matching track" ]
                    ]
            , div
                [ style "display" "flex"
                , style "flexDirection" "column"
                ]
                [ case selectedTrack of
                    Just spotifyTrack ->
                        a [ href spotifyTrack.href, target "_blank" ] [ text "Listen on Spotify" ]

                    Nothing ->
                        div [] []
                , if expanded then
                    div [] []

                  else
                    button [ onClick <| ExpandTrackMatches song.id ] [ text "Update Match" ]
                ]
            ]
        , if expanded then
            radiogroup []
                [ ul [] <| List.map (\track -> spotifyTrackListItem (Just track == selectedTrack) (SelectTrackForSong song track) track) song.spotifyMatches ]

          else
            div [] []
        ]
    )


serviceDetail : Model -> ServiceId -> Html Msg
serviceDetail model serviceId =
    let
        service =
            case Dict.get serviceId model.servicesById of
                Just s ->
                    s

                Nothing ->
                    { id = "", dates = "Unknown Service", serviceTypeId = "" }

        songs =
            case Dict.get serviceId model.songsByServiceId of
                Just s ->
                    s

                Nothing ->
                    []
    in
    div []
        [ h1 [] [ text service.dates ]
        , div
            [ style "display" "flex"
            , style "flexDirection" "column"
            ]
            [ a [ href "/services" ] [ text "Back to services" ]
            , label []
                [ text "Template Preset"
                , input
                    [ type_ "number"
                    , value <| String.fromInt model.basePreset
                    , onInput BasePresetChanged
                    ]
                    []
                ]
            , label []
                [ text "Starting Preset"
                , input
                    [ type_ "number"
                    , value <| String.fromInt model.startingPreset
                    , onInput StartingPresetChanged
                    ]
                    []
                ]
            , button [ onClick SendToDevice ] [ text "Send to Device" ]
            , if model.loadingServiceDetail then
                span [] [ text "Loading service songs..." ]

              else
                Html.Keyed.ul [ style "padding" "0px" ] <| List.map (songListItem model) songs
            ]
        ]


pluralize : String -> String -> List a -> String
pluralize singular plural xs =
    let
        count =
            List.length xs

        str =
            if count == 1 then
                singular

            else
                plural
    in
    String.fromInt count ++ " " ++ str


setlistItem : Setlist -> Html Msg
setlistItem setlist =
    div []
        [ h2 [] [ text setlist.name ]
        , div []
            [ text <| pluralize "song" "songs" setlist.songs ]
        , a
            [ href <| "/setlists/" ++ setlist.id ]
            [ text "View Setlist" ]
        , button [ onClick (RemoveSetlist setlist.id) ] [ text "Delete Setlist" ]
        ]


setlistsList : Model -> Html Msg
setlistsList model =
    let
        setlists : List Setlist
        setlists =
            Dict.toList model.setlistsById
                |> List.map Tuple.second
                |> List.sortBy .name
    in
    div []
        [ h1 [] [ text "Setlists" ]
        , p []
            [ a [ href "/setlists/new" ] [ text "New Setlist" ]
            ]
        , p [] [ text <| pluralize "setlist" "setlists" setlists ]
        , div [] <| List.map setlistItem setlists
        ]


keyOption : Key -> Key -> Html Msg
keyOption selectedKey key =
    option
        [ selected <| key == selectedKey
        ]
        [ text <| Key.toString key ]


setlistSongItem : (SongId -> Msg) -> (SongId -> Key -> Msg) -> (SongId -> String -> Msg) -> SetlistSong -> Html Msg
setlistSongItem onRemove onChangeKey onChangeTempo song =
    li []
        [ select
            [ onInput (\s -> onChangeKey song.id (Key.fromString s))
            ]
          <|
            List.map (keyOption (Key.fromString song.key)) allKeys
        , input
            [ type_ "number"
            , value <| String.fromInt song.tempo
            , onInput (onChangeTempo song.id)
            ]
            []
        , text <| "[" ++ song.key ++ "] " ++ song.title ++ " (" ++ String.fromInt song.tempo ++ " bpm)"
        , button [ onClick (onRemove song.id) ] [ text "Remove" ]
        ]


setlistDetail : Model -> String -> Html Msg
setlistDetail model setlistId =
    let
        maybeSetlist =
            Dict.get setlistId model.setlistsById
    in
    case maybeSetlist of
        Just setlist ->
            div []
                [ a [ href "/setlists" ] [ text "← Back to setlists" ]
                , h1 [] [ text setlist.name ]
                , addSongForm model
                , ul [] <| List.map (setlistSongItem (RemoveSongFromSetlist setlist.id) (UpdateSongKey setlist.id) (UpdateSongTempo setlist.id)) setlist.songs
                ]

        Nothing ->
            div [] [ text "Setlist Not Found" ]


spotifyTrackSuggestionItem : SpotifyTrack -> (SpotifyTrack -> Msg) -> Html Msg
spotifyTrackSuggestionItem track clickHandler =
    let
        imageUrl =
            case List.head <| List.filter (\i -> i.width == 64) track.album.images of
                Just image ->
                    image.url

                Nothing ->
                    "/images/compact-disc-1.svg"

        artistName =
            case List.head track.album.artists of
                Just artist ->
                    artist.name

                Nothing ->
                    "Unknown Artist"
    in
    li
        [ style "cursor" "pointer"
        , onClick <| clickHandler track
        ]
        [ img [ src imageUrl ] []
        , text track.name
        , text <| track.album.name ++ ", " ++ artistName
        ]


setlistForm : Model -> Msg -> Html Msg
setlistForm model msg =
    Html.form [ class "ui form", onSubmit msg ]
        [ h1 [] [ text "Create a Setlist" ]
        , div [ class "field" ]
            [ label [] [ text "Setlist Name" ]
            , input
                [ type_ "text"
                , placeholder "My Setlist"
                , value model.newSetlistName
                , onInput NewSetlistNameChanged
                ]
                []
            ]
        , button
            [ class
                (if String.length model.newSetlistName == 0 then
                    "ui disabled button"

                 else
                    "ui button"
                )
            ]
            [ text "Create Setlist" ]
        ]


addSongForm : Model -> Html Msg
addSongForm model =
    let
        setlistId =
            case model.route of
                Just (SetlistDetail id) ->
                    id

                _ ->
                    "unknown"
    in
    div []
        [ input
            [ type_ "text"
            , value model.songQuery
            , onInput
                (\str ->
                    SongQueryChanged str <|
                        provideInput <|
                            SongQueryChangedOneSecondAgo
                )
            ]
            []
        , ul [] <| List.map (\t -> spotifyTrackSuggestionItem t <| AddSpotifyTrackToSetlist setlistId) model.spotifyTracks
        ]


view : Model -> { title : String, body : List (Html Msg) }
view model =
    { title = "setbuilder.app"
    , body =
        [ div [ class "ui container" ]
            [ if model.loggedIn then
                case model.route of
                    Just ServicesList ->
                        if model.loadingServices then
                            div [] [ text "Loading Services..." ]

                        else
                            servicesList model

                    Just (ServiceDetail _ serviceId) ->
                        serviceDetail model serviceId

                    Just SetlistsList ->
                        if model.loadingSetlists then
                            div [] [ text "Loading Setlists..." ]

                        else
                            setlistsList model

                    Just (SetlistDetail setlistId) ->
                        setlistDetail model setlistId

                    Just SetlistCreate ->
                        setlistForm model SetlistCreateSubmit

                    Nothing ->
                        div [] [ text "Whoops! Page not found." ]

              else
                a [ href "/auth/pco/provider" ] [ text "Log in with PCO and Spotify" ]
            ]
        ]
    }
