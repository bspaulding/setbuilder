module Queries exposing (addSongToSetlistMutation, createSetlistMutation, removeSetlistMutation, removeSongFromSetlistMutation, runMutation, runQuery, serviceSongsQuery, servicesQuery, setlistsQuery, spotifyTracksQuery, updateSongMutation)

import GraphQL.Client.Http as GraphQLClient
import GraphQL.Request.Builder exposing (..)
import GraphQL.Request.Builder.Arg as Arg
import GraphQL.Request.Builder.Variable as Var
import Key exposing (Key)
import Model exposing (..)
import Task exposing (Task)


runQuery query args msg =
    GraphQLClient.sendQuery "/graphql" (request args query)
        |> Task.attempt msg


runMutation mutation args msg =
    GraphQLClient.sendMutation "/graphql" (request args mutation)
        |> Task.attempt msg


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
        |> with (field "key" [] int)


spotifyTrack =
    GraphQL.Request.Builder.object SpotifyTrack
        |> with (field "id" [] string)
        |> with (field "name" [] string)
        |> with (field "href" [] string)
        |> with (field "album" [] spotifyAlbum)
        |> with (field "features" [] spotifyTrackFeatures)


spotifyTracksQuery =
    let
        titleVar =
            Var.required "title" .title Var.string

        queryRoot =
            extract (field "spotifyTracks" [ ( "title", Arg.variable titleVar ) ] (GraphQL.Request.Builder.list spotifyTrack))
    in
    queryDocument queryRoot


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


setlistsQuery =
    let
        song =
            GraphQL.Request.Builder.object SetlistSong
                |> with (field "id" [] string)
                |> with (field "title" [] string)
                |> with (field "key" [] string)
                |> with (field "tempo" [] GraphQL.Request.Builder.int)

        setlist =
            GraphQL.Request.Builder.object Setlist
                |> with (field "id" [] string)
                |> with (field "name" [] string)
                |> with (field "songs" [] (GraphQL.Request.Builder.list song))

        queryRoot =
            extract (field "setlists" [] (GraphQL.Request.Builder.list setlist))
    in
    queryDocument queryRoot


serviceSongsQuery =
    let
        serviceIdVar =
            Var.required "serviceId" .serviceId Var.string

        serviceTypeIdVar =
            Var.required "serviceTypeId" .serviceTypeId Var.string

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


type alias CreateSetlistResponse =
    { id : String }


createSetlistMutation =
    let
        setlistNameVar =
            Var.required "name" .name Var.string

        setlist =
            GraphQL.Request.Builder.object CreateSetlistResponse
                |> with (field "id" [] string)

        queryRoot =
            extract
                (field "CreateSetlist"
                    [ ( "name", Arg.variable setlistNameVar ) ]
                    setlist
                )
    in
    mutationDocument queryRoot


type alias AddSongToSetlistResponse =
    { id : String, key : String, tempo : Int, title : String }


addSongToSetlistMutation =
    let
        setlistIdVar =
            Var.required "setlistId" .setlistId Var.id

        titleVar =
            Var.required "title" .title Var.string

        keyVar =
            Var.required "key" .key Var.string

        tempoVar =
            Var.required "tempo" .tempo Var.int

        response =
            GraphQL.Request.Builder.object AddSongToSetlistResponse
                |> with (field "id" [] string)
                |> with (field "key" [] string)
                |> with (field "tempo" [] int)
                |> with (field "title" [] string)

        queryRoot =
            extract
                (field "AddSongToSetlist"
                    [ ( "setlistId", Arg.variable setlistIdVar )
                    , ( "title", Arg.variable titleVar )
                    , ( "key", Arg.variable keyVar )
                    , ( "tempo", Arg.variable tempoVar )
                    ]
                    response
                )
    in
    mutationDocument queryRoot


removeSetlistMutation =
    let
        setlistIdVar =
            Var.required "setlistId" .setlistId Var.id

        queryRoot =
            extract (field "RemoveSetlist" [ ( "setlistId", Arg.variable setlistIdVar ) ] bool)
    in
    mutationDocument queryRoot


removeSongFromSetlistMutation =
    let
        setlistIdVar =
            Var.required "setlistId" .setlistId Var.id

        songIdVar =
            Var.required "songId" .songId Var.id

        queryRoot =
            extract
                (field "RemoveSongFromSetlist"
                    [ ( "setlistId", Arg.variable setlistIdVar )
                    , ( "songId", Arg.variable songIdVar )
                    ]
                    bool
                )
    in
    mutationDocument queryRoot


type alias UpdateSongResponse =
    { id : String, key : String, tempo : Int, title : String }


updateSongMutation =
    let
        setlistIdVar =
            Var.required "setlistId" .setlistId Var.id

        songIdVar =
            Var.required "songId" .songId Var.id

        titleVar =
            Var.optional "title" .title (Var.nullable Var.string) Nothing

        keyVar =
            Var.optional "key" .key (Var.nullable Var.string) Nothing

        tempoVar =
            Var.optional "tempo" .tempo (Var.nullable Var.int) Nothing

        response =
            GraphQL.Request.Builder.object UpdateSongResponse
                |> with (field "id" [] string)
                |> with (field "key" [] string)
                |> with (field "tempo" [] int)
                |> with (field "title" [] string)

        queryRoot =
            extract
                (field "UpdateSong"
                    [ ( "setlistId", Arg.variable setlistIdVar )
                    , ( "songId", Arg.variable songIdVar )
                    , ( "title", Arg.variable titleVar )
                    , ( "key", Arg.variable keyVar )
                    , ( "tempo", Arg.variable tempoVar )
                    ]
                    response
                )
    in
    mutationDocument queryRoot
