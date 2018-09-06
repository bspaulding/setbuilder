const UglifyJsPlugin = require('uglifyjs-webpack-plugin');
const CompressionPlugin = require('compression-webpack-plugin');

module.exports = {
	mode: 'production',
	entry: './src/client.js',
	output: {
		filename: './public/client.js'
	},
	resolve: {
		symlinks: false
	},
	module: {
		rules: [
			{
				test: /\.elm$/,
				exclude: [/elm-stuff/, /node_modules/],
				use: {
					loader: 'elm-webpack-loader',
					options: {
						optimize: true
					}
				}
			}
		]
	},
	plugins: [new UglifyJsPlugin(), new CompressionPlugin()]
};
