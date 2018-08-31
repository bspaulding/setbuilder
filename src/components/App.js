import React from 'react';
import gql from 'graphql-tag';
import { Query } from 'react-apollo';
import ServicesList from './ServicesList';
import ServiceDetail from './ServiceDetail';

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
