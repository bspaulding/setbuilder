import React from 'react';
import gql from 'graphql-tag';
import { Query } from 'react-apollo';
import ServicesList from './ServicesList';
import ServiceDetail from './ServiceDetail';
import * as AxeFxMIDI from 'axe-fx-midi';

window.AxeFxMIDI = AxeFxMIDI;
const isFractal = d => d.manufacturer === 'Fractal Audio Systems';
(async function() {
	const devices = await navigator.requestMIDIAccess({ sysex: true });
	const input = Array.from(devices.inputs.values()).find(isFractal);
	const output = Array.from(devices.outputs.values()).find(isFractal);
	input.onmidimessage = event => {
		const msg = Array.from(event.data.values());
		const parsed = AxeFxMIDI.parseMessage(msg);
		if (parsed.type !== 'midi-tempo-beat') {
			console.log(parsed);
		}
	};

	function setupSong({ model, basePreset, targetPreset, tempo, title, key }) {
		return [
			AxeFxMIDI.setPresetNumber(model, basePreset),
			AxeFxMIDI.setTempo(model, tempo),
			AxeFxMIDI.setPresetName(model, `[${key}] ${title}`),
			AxeFxMIDI.storeInPreset(model, targetPreset),
			AxeFxMIDI.setPresetNumber(model, targetPreset)
		];
	}
	const setupSongs = ({ model, basePreset, startingPreset }) => songs =>
		songs.flatMap(({ key, title, tempo }, i) =>
			setupSong({
				model,
				basePreset,
				key,
				title,
				tempo,
				targetPreset: i + startingPreset
			})
		);
	window.output = output;
	window.setupSongs = setupSongs;
})();

const queryServices = gql`
	{
		services {
			id
			dates
			serviceTypeId
		}
	}
`;

const App = ({ onSelectService, selectedService, loggedIn }) =>
	loggedIn ? (
		<React.Fragment>
			<Query
				query={gql`
					{
						owner {
							firstName
							lastName
							avatarURL
						}
					}
				`}
			>
				{({ loading, error, data }) =>
					!loading && (
						<div style={{ display: 'flex' }}>
							<img
								src={data.owner.avatarURL}
								style={{ width: 100, height: 100, borderRadius: 50 }}
							/>
							<h1>
								{data.owner.firstName} {data.owner.lastName}
							</h1>
						</div>
					)
				}
			</Query>
			{selectedService ? (
				<ServiceDetail
					service={selectedService}
					onViewList={() => onSelectService(undefined)}
				/>
			) : (
				<Query query={queryServices}>
					{({ loading, error, data }) => {
						if (loading) {
							return 'Loading services...';
						}
						if (error) {
							return 'Loading services failed.';
						}
						return (
							<ServicesList
								services={data.services}
								onSelectService={onSelectService}
							/>
						);
					}}
				</Query>
			)}
		</React.Fragment>
	) : (
		<a href="/auth/pco/provider">Log in with Planning Center &amp; Spotify</a>
	);

class AppWrapper extends React.Component {
	render() {
		return (
			<App
				{...this.props}
				{...this.state}
				onSelectService={selectedService => this.setState({ selectedService })}
			/>
		);
	}
}
export default AppWrapper;
