port module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Dict exposing (Dict)
import GraphQL.Client.Http as GraphQLClient
import GraphQL.Request.Builder exposing (..)
import GraphQL.Request.Builder.Arg as Arg
import GraphQL.Request.Builder.Variable as Var
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Task exposing (Task)
import Url
import Url.Parser exposing ((</>), Parser, int, map, oneOf, s, top)


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


makeSetupSongsPacket : List ( Song, Maybe SpotifyTrack ) -> SetupSongsPacket
makeSetupSongsPacket songs =
    { basePreset = 205
    , startingPreset = 217
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
        |> Maybe.map makeSetupSongsPacket


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
    | ExpandTrackMatches SongId
    | SelectTrackForSong Song SpotifyTrack
    | SendToDevice
    | UrlChanged Url.Url
    | LinkClicked Browser.UrlRequest


type alias Model =
    { key : Nav.Key
    , route : Maybe Route
    , loggedIn : Bool
    , loadingServices : Bool
    , loadingServiceDetail : Bool
    , servicesById : Dict String Service
    , songsByServiceId : Dict String (List Song)
    , selectedTrackIdBySongId : Dict SongId SpotifyTrackId
    , expandedBySongId : Dict SongId Bool
    }


type alias Flags =
    { loggedIn : Bool }


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        route =
            Url.Parser.parse routeParser url
    in
    ( case route of
        Just ServicesList ->
            Model key route flags.loggedIn True False Dict.empty Dict.empty Dict.empty Dict.empty

        Just (ServiceDetail _ _) ->
            Model key route flags.loggedIn True True Dict.empty Dict.empty Dict.empty Dict.empty

        _ ->
            Model key route flags.loggedIn False False Dict.empty Dict.empty Dict.empty Dict.empty
    , if flags.loggedIn then
        case route of
            Just ServicesList ->
                getServices

            Just (ServiceDetail serviceTypeId serviceId) ->
                Cmd.batch [ getServices, getServiceSongs { serviceId = serviceId, serviceTypeId = serviceTypeId } ]

            _ ->
                Cmd.none

      else
        Cmd.none
    )


type alias ServiceId =
    String


type alias ServiceTypeId =
    String


type Route
    = ServicesList
    | ServiceDetail ServiceTypeId ServiceId


routeParser : Parser (Route -> a) a
routeParser =
    oneOf
        [ map ServicesList top
        , map ServicesList (s "services")
        , map ServiceDetail (s "services" </> s "types" </> Url.Parser.string </> s "service" </> Url.Parser.string)
        ]


update msg model =
    case msg of
        ServicesReceived (Ok services) ->
            ( { model
                | servicesById = Dict.fromList <| List.map (\service -> ( service.id, service )) services
                , loadingServices = False
              }
            , Cmd.none
            )

        ServiceSongsReceived serviceId (Ok songs) ->
            ( { model
                | loadingServiceDetail = False
                , songsByServiceId = Dict.insert serviceId songs model.songsByServiceId
              }
            , Cmd.none
            )

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

        _ ->
            ( model, Cmd.none )


subscriptions _ =
    Sub.none


serviceListItem : Service -> Html Msg
serviceListItem service =
    li [] [ a [ href ("/services/types/" ++ service.serviceTypeId ++ "/service/" ++ service.id) ] [ text service.dates ] ]


servicesList : Model -> Html Msg
servicesList model =
    let
        services =
            Dict.values model.servicesById
    in
    div []
        [ h1 [] [ text "Services" ]
        , text <| (String.fromInt <| List.length services) ++ " services"
        , ul [] <| List.map serviceListItem services
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


songListItem : Model -> Song -> Html Msg
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
    li
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
            ]
        , if expanded then
            radiogroup []
                [ ul [] <| List.map (\track -> spotifyTrackListItem (Just track == selectedTrack) (SelectTrackForSong song track) track) song.spotifyMatches ]

          else
            button [ onClick <| ExpandTrackMatches song.id ] [ text "Update Match" ]
        ]


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
        , a [ href "/services" ] [ text "Back to services" ]
        , button [ onClick SendToDevice ] [ text "Send to Device" ]
        , if model.loadingServiceDetail then
            span [] [ text "Loading service songs..." ]

          else
            ul [] <| List.map (songListItem model) songs
        ]


view model =
    { title = "setbuilder.app"
    , body =
        [ if model.loggedIn then
            case model.route of
                Just ServicesList ->
                    if model.loadingServices then
                        div [] [ text "Loading Services..." ]

                    else
                        servicesList model

                Just (ServiceDetail _ serviceId) ->
                    serviceDetail model serviceId

                Nothing ->
                    div [] [ text "Whoops! Page not found." ]

          else
            a [ href "/auth/pco/provider" ] [ text "Log in with PCO and Spotify" ]
        ]
    }


type alias Service =
    { id : String
    , dates : String
    , serviceTypeId : String
    }


servicesQuery =
    let
        service =
            GraphQL.Request.Builder.object Service
                |> with (field "id" [] string)
                |> with (field "dates" [] string)
                |> with (field "serviceTypeId" [] string)

        queryRoot =
            extract
                (field "services" [] (GraphQL.Request.Builder.list service))
    in
    queryDocument queryRoot


getServices =
    GraphQLClient.sendQuery "/graphql" (request [] servicesQuery)
        |> Task.attempt ServicesReceived


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
    { tempo : Float }


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


serviceSongsQuery =
    let
        serviceIdVar =
            Var.required "serviceId" .serviceId Var.string

        serviceTypeIdVar =
            Var.required "serviceTypeId" .serviceTypeId Var.string

        spotifyAlbumImage =
            GraphQL.Request.Builder.object SpotifyAlbumImage
                |> with (field "height" [] GraphQL.Request.Builder.int)
                |> with (field "width" [] GraphQL.Request.Builder.int)
                |> with (field "url" [] string)

        spotifyArtist =
            GraphQL.Request.Builder.object SpotifyArtist
                |> with (field "name" [] string)

        spotifyAlbum =
            GraphQL.Request.Builder.object SpotifyAlbum
                |> with (field "name" [] string)
                |> with (field "artists" [] (GraphQL.Request.Builder.list spotifyArtist))
                |> with (field "images" [] (GraphQL.Request.Builder.list spotifyAlbumImage))

        spotifyTrackFeatures =
            GraphQL.Request.Builder.object SpotifyTrackFeatures
                |> with (field "tempo" [] float)

        spotifyTrack =
            GraphQL.Request.Builder.object SpotifyTrack
                |> with (field "id" [] string)
                |> with (field "name" [] string)
                |> with (field "href" [] string)
                |> with (field "album" [] spotifyAlbum)
                |> with (field "features" [] spotifyTrackFeatures)

        song =
            GraphQL.Request.Builder.object Song
                |> with (field "id" [] string)
                |> with (field "title" [] string)
                |> with (field "key" [] string)
                |> with (field "spotifyMatches" [] (GraphQL.Request.Builder.list spotifyTrack))

        queryRoot =
            extract
                (field "getServiceSongs"
                    [ ( "serviceId", Arg.variable serviceIdVar )
                    , ( "serviceTypeId", Arg.variable serviceTypeIdVar )
                    ]
                    (GraphQL.Request.Builder.list song)
                )
    in
    queryDocument queryRoot


getServiceSongs : { serviceId : String, serviceTypeId : String } -> Cmd Msg
getServiceSongs args =
    GraphQLClient.sendQuery "/graphql" (request args serviceSongsQuery)
        |> Task.attempt (ServiceSongsReceived args.serviceId)
