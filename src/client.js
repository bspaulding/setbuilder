import { Elm } from './Main.elm';
import { guessModel, setupSongs, connect } from './MIDI';

const app = Elm.Main.init({
	flags: window.__INITIAL_PROPS__
});

app.ports.setupSongs.subscribe(async data => {
	const { output } = await connect({ logParsedMessages: true });
	const { basePreset, startingPreset, songs } = data;
	setupSongs({
		model: guessModel(output.name),
		basePreset,
		startingPreset
	})(songs).map(msg => output.send(msg));
});
