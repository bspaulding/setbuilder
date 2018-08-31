import https from 'https';
import express from 'express';
import session from 'express-session';
import connectRedis from 'connect-redis';
import redis from 'redis';
import passport from 'passport';
import OAuth2Strategy from 'passport-oauth2';
import bodyParser from 'body-parser';
import { ApolloServer } from 'apollo-server-express';
import { typeDefs, resolvers } from './schema';
import { getUserInfo as getPCOUserInfo } from './api/PCOApi';
import { getUserInfo as getSpotifyUserInfo } from './api/SpotifyApi';

const redisClient = redis.createClient();
redisClient.on('connect', () => console.log('Redis client connected'));
const RedisStore = connectRedis(session);
const app = express();

passport.use(
	'pco-oauth',
	new OAuth2Strategy(
		{
			tokenURL: 'https://api.planningcenteronline.com/oauth/token',
			authorizationURL: 'https://api.planningcenteronline.com/oauth/authorize',
			clientID: process.env.PCO_CLIENT_ID,
			clientSecret: process.env.PCO_CLIENT_SECRET,
			callbackURL: 'http://localhost:3000/auth/pco/complete',
			scope: 'people services'
		},
		async (accessToken, refreshToken, profile, done) => {
			const userResponse = await getPCOUserInfo({
				headers: {
					Authorization: `Bearer ${accessToken}`
				}
			});
			const user = {
				...userResponse.data,
				accessToken,
				refreshToken
			};
			redisClient.set(`user-${user.id}`, JSON.stringify(user), () =>
				done(null, user)
			);
		}
	)
);

passport.use(
	'spotify-oauth',
	new OAuth2Strategy(
		{
			tokenURL: 'https://accounts.spotify.com/api/token',
			authorizationURL: 'https://accounts.spotify.com/authorize',
			clientID: process.env.SPOTIFY_CLIENT_ID,
			clientSecret: process.env.SPOTIFY_CLIENT_SECRET,
			callbackURL: 'http://localhost:3000/auth/spotify/complete',
			scope: 'user-read-email'
		},
		async (accessToken, refreshToken, profile, done) => {
			const user = await getSpotifyUserInfo({
				headers: {
					Authorization: `Bearer ${accessToken}`
				}
			});
			done(null, {
				...user,
				accessToken,
				refreshToken
			});
		}
	)
);

const gqlServer = new ApolloServer({
	typeDefs,
	resolvers,
	context: ({ req }) => ({
		user: req.user
	})
});

app.use(express.static('dist/public'));
app.use(bodyParser.json());
app.use(
	session({
		resave: false,
		saveUninitialized: false,
		secret: 'axe-fx-pco-set-builder',
		store: new RedisStore({
			client: redisClient
		})
	})
);
app.use(passport.initialize());
app.use(passport.session());
gqlServer.applyMiddleware({ app });

passport.serializeUser((user, done) => {
	done(null, user.id);
});

passport.deserializeUser((userId, done) => {
	redisClient.get(`user-${userId}`, (error, result) => {
		done(null, (result && JSON.parse(result)) || null);
	});
});

app.get('/auth/pco/provider', passport.authenticate('pco-oauth'));

app.get(
	'/auth/pco/complete',
	passport.authenticate('pco-oauth', {
		session: true,
		successRedirect: '/auth/spotify/provider',
		failureRedirect: '/auth/pco/failed'
	})
);

app.get('/auth/spotify/provider', passport.authorize('spotify-oauth'));

app.get(
	'/auth/spotify/complete',
	passport.authorize('spotify-oauth', {
		successRedirect: '/',
		failureRedirect: '/auth/spotify/failed'
	}),
	(request, response) => {
		const user = request.user;
		const account = request.account;
		redisClient.set(
			`user-${user.id}`,
			JSON.stringify({
				...user,
				spotifyAccount: account
			}),
			() => response.redirect('/')
		);
	}
);

const html = props => `
<!DOCTYPE html>
<html>
<head>
<title>Axe-Fx / PCO Setlist Builder</title>
</head>
<body>
	<div id="app"></div>
	<script>
		window.__INITIAL_PROPS__ = ${JSON.stringify(props)};
	</script>
	<script src="client.js"></script>
</body>
</html>
`;
app.get('/', (request, response) => {
	response.send(html({ loggedIn: !!request.user }));
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
	/* eslint-disable no-console */
	console.log(`Listening on port ${port}...`);
	console.log(`GraphQL available at: ${gqlServer.graphqlPath}`);
});
