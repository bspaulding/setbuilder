import React from 'react';
import gql from 'graphql-tag';
import { Query } from 'react-apollo';
import { connect, setupSongs, guessModel } from '../MIDI';

const queryServiceSongs = gql`
	query queryServiceSongs($serviceId: String, $serviceTypeId: String) {
		getServiceSongs(serviceId: $serviceId, serviceTypeId: $serviceTypeId) {
			id
			title
			key
			spotifyMatches {
				id
				name
				href
				album {
					name
					artists {
						name
					}
					images {
						height
						width
						url
					}
				}
				features {
					tempo
				}
			}
		}
	}
`;

class ServiceSongItem extends React.Component {
	constructor(props) {
		super();
		this.state = {
			expandMatches: false
		};
	}

	onSelectTrack(selectedTrack) {
		this.setState({ expandMatches: false });
		this.props.onSelectTrack(selectedTrack);
	}

	render() {
		const { song, selectedTrack } = this.props;
		const { expandMatches } = this.state;
		return (
			<li key={song.id}>
				<div style={{ display: 'flex', flexDirection: 'column' }}>
					<div style={{ display: 'flex', flexDirection: 'row' }}>
						<img
							style={{ width: 64, height: 64 }}
							src={selectedTrack.album.images.find(i => i.width === 64).url}
						/>
						<div style={{ display: 'flex', flexDirection: 'column' }}>
							<span>{song.title}</span>
							<span>{selectedTrack.album.name}</span>
							<span>
								{selectedTrack.album.artists.map(a => a.name).join(', ')}
							</span>
							<span>
								{song.key} - {parseInt(selectedTrack.features.tempo, 10)} bpm
							</span>
						</div>
					</div>
					{!expandMatches && (
						<div style={{ display: 'flex', flexDirection: 'row' }}>
							<button onClick={() => this.setState({ expandMatches: true })}>
								Update Match
							</button>
						</div>
					)}
				</div>
				{expandMatches && (
					<ol>
						{song.spotifyMatches.map(track => (
							<li key={track.id} onClick={this.onSelectTrack.bind(this, track)}>
								<div style={{ display: 'flex', flexDirection: 'column' }}>
									<div style={{ display: 'flex', flexDirection: 'row' }}>
										<img
											style={{ width: 64, height: 64 }}
											src={track.album.images.find(i => i.width === 64).url}
										/>
										<div
											style={{
												display: 'flex',
												flexDirection: 'column'
											}}
										>
											<span>{track.name}</span>
											<span>{track.album.name}</span>
											<span>
												{track.album.artists.map(a => a.name).join(', ')}
											</span>
											<span>{parseInt(track.features.tempo, 10)} bpm</span>
										</div>
									</div>
									<div>
										<a href={track.href} target="_blank">
											Open in Spotify
										</a>
									</div>
								</div>
							</li>
						))}
					</ol>
				)}
			</li>
		);
	}
}

class ServiceDetail extends React.Component {
	constructor(props) {
		super();
		this.state = {
			basePreset: 209,
			selectedTracksBySongId: props.songs.reduce((byId, song) => {
				byId[song.id] = song.spotifyMatches[0];
				return byId;
			}, {})
		};
	}

	async sendToAxeFx() {
		const { output } = await connect();
		const msgs = setupSongs({
			model: guessModel(output.name),
			basePreset: this.state.basePreset,
			startingPreset: 217
		})(
			this.props.songs.map(song => ({
				key: song.key,
				title: song.title,
				tempo: this.state.selectedTracksBySongId[song.id].features.tempo
			}))
		);
		msgs.map(msg => output.send(msg));
	}

	render() {
		const { songs } = this.props;
		return (
			<React.Fragment>
				<input
					type="number"
					value={this.state.basePreset}
					onChange={event =>
						this.setState({ basePreset: parseInt(event.target.value, 10) })
					}
				/>
				<span>{songs.length} song(s)</span>
				<button onClick={this.sendToAxeFx.bind(this)}>Send to Axe-Fx</button>
				<ol>
					{songs.map(song => (
						<ServiceSongItem
							key={song.id}
							song={song}
							selectedTrack={this.state.selectedTracksBySongId[song.id]}
							onSelectTrack={track =>
								this.setState(({ selectedTracksBySongId }) => ({
									selectedTracksBySongId: {
										...selectedTracksBySongId,
										[song.id]: track
									}
								}))
							}
						/>
					))}
				</ol>
			</React.Fragment>
		);
	}
}

class ServiceDetailWrapper extends React.Component {
	render() {
		const selectedService = this.props.service;
		return (
			<React.Fragment>
				<button onClick={this.props.onViewList}>Back to services</button>
				<h1>{selectedService.dates}</h1>
				<Query
					query={queryServiceSongs}
					variables={{
						serviceId: selectedService.id,
						serviceTypeId: selectedService.serviceTypeId
					}}
				>
					{({ loading, error, data }) => (
						<React.Fragment>
							{loading ? (
								'Loading songs..'
							) : error ? (
								'Loading songs failed! 😥'
							) : (
								<ServiceDetail songs={data.getServiceSongs} />
							)}
						</React.Fragment>
					)}
				</Query>
			</React.Fragment>
		);
	}
}

export default ServiceDetailWrapper;
