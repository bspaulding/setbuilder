module Queries exposing (runQuery, serviceSongsQuery, servicesQuery, setlistsQuery, spotifyTracksQuery)

import GraphQL.Client.Http as GraphQLClient
import GraphQL.Request.Builder exposing (..)
import GraphQL.Request.Builder.Arg as Arg
import GraphQL.Request.Builder.Variable as Var
import Model exposing (..)
import Task exposing (Task)


runQuery query args msg =
    GraphQLClient.sendQuery "/graphql" (request args query)
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
