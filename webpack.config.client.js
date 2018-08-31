module.exports = {
	mode: 'development',
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
				test: /\.js$/,
				exclude: /node_modules/,
				use: {
					loader: 'babel-loader',
					options: {
						presets: [
							'react',
							[
								'env',
								{
									targets: {
										browsers: ['last 2 versions']
									}
								}
							]
						]
					}
				}
			}
		]
	}
};
