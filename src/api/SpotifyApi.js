import https from 'https';

export const getUserInfo = ({ headers }) =>
	new Promise(resolve => {
		https.get(
			{
				hostname: 'api.spotify.com',
				path: '/v1/me',
				headers
			},
			userResponse => {
				var body = '';
				userResponse.on('data', data => {
					body += data.toString('utf8');
				});
				userResponse.on('end', () => {
					resolve(JSON.parse(body));
				});
			}
		);
	});

export const searchTracksByTitle = ({ headers, title, limit }) =>
	new Promise(resolve => {
		https.get(
			{
				hostname: 'api.spotify.com',
				path: `/v1/search?q=${encodeURIComponent(
					title
				)}&type=track&limit=${limit}`,
				headers
			},
			songsResponse => {
				var body = '';
				songsResponse.on('data', data => {
					body += data.toString('utf8');
				});
				songsResponse.on('end', () => {
					const tracksResponse = JSON.parse(body);
					resolve(tracksResponse.tracks.items);
				});
			}
		);
	});

export const getTrackFeatures = ({ headers, trackId }) =>
	new Promise(resolve => {
		https.get(
			{
				hostname: 'api.spotify.com',
				path: `/v1/audio-features/${trackId}`,
				headers
			},
			featuresR => {
				var body = '';
				featuresR.on('data', data => {
					body += data.toString('utf8');
				});
				featuresR.on('end', () => {
					const features = JSON.parse(body);

					console.log({ features });
					resolve(features);
				});
			}
		);
	});
