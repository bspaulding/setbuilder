const UglifyJsPlugin = require('uglifyjs-webpack-plugin');
const CompressionPlugin = require('compression-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

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
				test: /\.css$/,
				use: [
					{
						loader: MiniCssExtractPlugin.loader
					},
					'css-loader'
				]
			},
			{
				test: /\.(svg|eot|png|woff|woff2|ttf)$/,
				use: ['file-loader']
			},
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
	plugins: [
		new UglifyJsPlugin(),
		new CompressionPlugin(),
		new MiniCssExtractPlugin({
			filename: './public/[name].css'
		})
	]
};
