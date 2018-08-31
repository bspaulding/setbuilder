import 'babel-polyfill';
import React from 'react';
import { render } from 'react-dom';
import App from './components/App';
import { ApolloProvider } from 'react-apollo';
import ApolloClient from 'apollo-boost';

const client = new ApolloClient();

render(
	<ApolloProvider client={client}>
		<App {...window.__INITIAL_PROPS__} />
	</ApolloProvider>,
	document.querySelector('#app')
);
