import * as AxeFxMIDI from 'axe-fx-midi';

const isFractal = d => d.manufacturer === 'Fractal Audio Systems';

export const guessModel = deviceName => {
	if (deviceName.indexOf('AXE-FX II') >= 0) {
		return AxeFxMIDI.models.ii;
	} else if (deviceName.indexOf('AX8') >= 0) {
		return AxeFxMIDI.models.ax8;
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

export const setupSongs = ({ model, basePreset, startingPreset }) => songs =>
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

export async function connect({ logParsedMessages = false } = {}) {
	const devices = await navigator.requestMIDIAccess({ sysex: true });
	const input = Array.from(devices.inputs.values()).find(isFractal);
	const output = Array.from(devices.outputs.values()).find(isFractal);

	if (logParsedMessages) {
		input.onmidimessage = event => {
			const msg = Array.from(event.data.values());
			const parsed = AxeFxMIDI.parseMessage(msg);
			if (parsed.type !== 'midi-tempo-beat') {
				/* eslint-disable no-console */
				console.log(parsed);
				/* eslint-enable no-console */
			}
		};
	}

	return { input, output };
}
