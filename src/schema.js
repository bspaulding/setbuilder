import { gql } from 'apollo-server-express';
import { getAllPlans, getPlanSongs } from './api/PCOApi';
import { getTrackFeatures, searchTracksByTitle } from './api/SpotifyApi';

export const typeDefs = gql`
	type SpotifyTrackFeatures {
		danceability: Float
		energy: Float
		key: Int
		loudness: Float
		mode: Int
		speechiness: Float
		acousticness: Float
		instrumentalness: Float
		liveness: Float
		valence: Float
		tempo: Float
		duration_ms: Int
		time_signature: Int
	}
	type SpotifyArtist {
		id: ID
		name: String
		href: String
	}
	type SpotifyAlbumImage {
		height: Int
		width: Int
		url: String
	}
	type SpotifyAlbum {
		id: ID
		name: String
		href: String
		artists: [SpotifyArtist]
		images: [SpotifyAlbumImage]
	}
	type SpotifyTrack {
		id: ID
		name: String
		href: String
		artists: [SpotifyArtist]
		album: SpotifyAlbum
		features: SpotifyTrackFeatures
	}
	type Song {
		id: ID
		title: String
		key: String
		spotifyMatches: [SpotifyTrack]
	}
	type Service {
		id: ID
		dates: String
		serviceTypeId: String
		songs: [Song]
	}
	type User {
		firstName: String
		lastName: String
		avatarURL: String
	}
	type Query {
		owner: User
		services: [Service]
		getServiceSongs(serviceId: String, serviceTypeId: String): [Song]
	}
`;

const songItemMapper = song => ({
	id: song.relationships.song.data.id,
	title: song.attributes.title,
	key: song.attributes.key_name
});

export const resolvers = {
	Query: {
		services: async (parent, args, context, info) => {
			const headers = {
				Authorization: `Bearer ${context.user.accessToken}`
			};
			const plans = await getAllPlans({ headers });
			return plans.map(plan => ({
				id: plan.id,
				dates: plan.attributes.dates,
				serviceTypeId: plan.relationships.service_type.data.id,
				_meta: plan
			}));
		},
		getServiceSongs: async (parent, args, context, info) => {
			return (await getPlanSongs({
				planId: args.serviceId,
				serviceTypeId: args.serviceTypeId,
				headers: {
					Authorization: `Bearer ${context.user.accessToken}`
				}
			})).map(songItemMapper);
		},
		owner: (parent, args, context, info) => ({
			firstName: context.user.attributes.first_name,
			lastName: context.user.attributes.last_name,
			avatarURL: context.user.attributes.avatar
		})
	},
	Service: {
		songs: async (parent, args, context, info) => {
			return (await getPlanSongs({
				planId: parent.id,
				serviceTypeId: parent.serviceTypeId,
				headers: {
					Authorization: `Bearer ${context.user.accessToken}`
				}
			})).map(songItemMapper);
		}
	},
	Song: {
		spotifyMatches: async (song, args, context, info) => {
			const tracks = await searchTracksByTitle({
				title: song.title,
				limit: 5,
				headers: {
					Authorization: `Bearer ${context.user.spotifyAccount.accessToken}`
				}
			});
			return tracks.map(track => ({
				...track,
				href: track.external_urls.spotify
			}));
		}
	},
	SpotifyTrack: {
		features: async (track, args, context, info) => {
			return await getTrackFeatures({
				trackId: track.id,
				headers: {
					Authorization: `Bearer ${context.user.spotifyAccount.accessToken}`
				}
			});
		}
	}
};
