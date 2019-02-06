import { promisify } from 'util';
import { gql } from 'apollo-server-express';
import { getAllPlans, getPlanSongs } from './api/PCOApi';
import { getTrackFeatures, searchTracksByTitle } from './api/SpotifyApi';
import uuid from 'uuid/v4';

const redisGetPromise = (redisOp, key) =>
	new Promise((resolve, reject) => {
		redisOp(key, (error, result) => {
			if (error) {
				reject(error);
			} else {
				resolve(result);
			}
		});
	});

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
		tempo: Int
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
	type Setlist {
		id: ID
		name: String
		songs: [Song]
	}
	type Query {
		owner: User
		services: [Service]
		getServiceSongs(serviceId: String, serviceTypeId: String): [Song]
		setlists: [Setlist]
	}
	type Mutation {
		CreateSetlist(name: String!): Setlist
		AddSongToSetlist(
			setlistId: ID!
			title: String!
			key: String
			tempo: Int
		): Song
		RemoveSongFromSetlist(setlistId: ID!, songId: ID!): Boolean
		UpdateSong(
			setlistId: ID!
			songId: ID!
			title: String
			key: String
			tempo: Int
		): Song
		RemoveSetlist(setlistId: ID!): Boolean
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
		}),
		setlists: async (parent, args, context, info) => {
			const { redis, user } = context;
			const ids = await redisGetPromise(
				redis.smembers.bind(redis),
				`user-${user.id}-setlist-ids`
			);
			const setlists = (await Promise.all(
				(ids || []).map(id =>
					redisGetPromise(
						redis.get.bind(redis),
						`user-${user.id}-setlist-${id}`
					)
				)
			)).map(JSON.parse);
			return setlists;
		}
	},
	Setlist: {
		songs: async (setlist, args, context, info) => {
			const { user, redis } = context;
			const zrangebyscore = promisify(redis.zrangebyscore).bind(redis);
			const songIds = await zrangebyscore(
				`user-${user.id}-setlist-${setlist.id}-song-ids`,
				'-inf',
				'+inf'
			);
			const songs = (await Promise.all(
				(songIds || []).map(id =>
					redisGetPromise(redis.get.bind(redis), `song-${id}`)
				)
			)).map(JSON.parse);
			return songs;
		}
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
	},
	Mutation: {
		CreateSetlist: (parent, args, context, info) => {
			const { redis, user } = context;
			const { name } = args;
			const id = uuid();
			redis.sadd(`user-${user.id}-setlist-ids`, id);
			redis.set(`user-${user.id}-setlist-${id}`, JSON.stringify({ id, name }));
			return { id, name };
		},
		AddSongToSetlist: (parent, args, context, info) => {
			const { redis, user } = context;
			const id = uuid();
			const { title, key = 'C', tempo = 120, setlistId } = args;
			const song = { id, title, key, tempo };
			redis.set(`song-${id}`, JSON.stringify(song));
			redis.zadd(`user-${user.id}-setlist-${setlistId}-song-ids`, 1, id);
			return song;
		},
		RemoveSongFromSetlist: (parent, args, context, info) => {
			const { setlistId, songId } = args;
			const { redis, user } = context;
			redis.del(`song-${songId}`);
			redis.zrem(`user-${user.id}-setlist-${setlistId}-song-ids`, songId);
			return true;
		},
		UpdateSong: async (parent, args, { redis }, info) => {
			const { songId, title, key, tempo } = args;
			const song = JSON.parse(
				await redisGetPromise(redis.get.bind(redis), `song-${songId}`)
			);
			const newSong = {
				...song,
				title: title || song.title,
				key: key || song.key,
				tempo: tempo || song.tempo
			};
			redis.set(`song-${songId}`, JSON.stringify(newSong));
			return newSong;
		},
		RemoveSetlist: async (parent, { setlistId }, { redis, user }, info) => {
			const songIds = await redisGetPromise(
				redis.smembers.bind(redis),
				`user-${user.id}-setlist-${setlistId}-song-ids`
			);
			songIds.map(id => redis.del(`song-${id}`));
			redis.del(`user-${user.id}-setlist-${setlistId}-song-ids`);
			redis.srem(`user-${user.id}-setlist-ids`, setlistId);
			console.log({ songIds });
			return true;
		}
	}
};
