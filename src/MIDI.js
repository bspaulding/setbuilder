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

let listenersByType = {};
const getListeners = msgType => listenersByType[msgType] || [];
const addEventListener = (msgType, fn) => {
	if (!listenersByType[msgType]) {
		listenersByType[msgType] = [];
	}
	listenersByType[msgType].push(fn);
};

const removeEventListener = (msgType, fn) => {
	setTimeout(() => {
		if (!listenersByType[msgType]) {
			listenersByType[msgType] = [];
		}
		listenersByType[msgType] = listenersByType[msgType].filter(f => f !== fn);
	}, 0);
};

export function getPresetName(n) {
	return new Promise(async resolve => {
		const handler = msg => {
			console.log('handler!', { msg });
			removeEventListener('get-preset-name', handler);
			resolve(msg.value);
		};
		const { output } = await connect();
		const model = guessModel(output.name);
		output.send(AxeFxMIDI.setPresetNumber(model, n));
		addEventListener('get-preset-name', handler);
		output.send(AxeFxMIDI.getPresetName(model));
	});
}

export async function connect({ logParsedMessages = true } = {}) {
	const devices = await navigator.requestMIDIAccess({ sysex: true });
	const input = Array.from(devices.inputs.values()).find(isFractal);
	const output = Array.from(devices.outputs.values()).find(isFractal);

	if (!input.onmidimessage) {
		input.onmidimessage = event => {
			const msg = Array.from(event.data.values());
			const parsed = AxeFxMIDI.parseMessage(msg);
			if (logParsedMessages && parsed.type !== 'midi-tempo-beat') {
				/* eslint-disable no-console */
				console.log(parsed);
				/* eslint-enable no-console */
			}
			getListeners(parsed.type).forEach(f => f(parsed));
		};
	}

	return { input, output };
}
