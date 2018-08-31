var Dotenv = require('dotenv-webpack');

module.exports = {
	mode: 'development',
	target: 'node',
	entry: './src/server.js',
	output: {
		filename: 'server.js'
	},
	resolve: {
		extensions: ['.js'],
		mainFields: ['main']
	},
	plugins: [new Dotenv()]
};
