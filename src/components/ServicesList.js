import React from 'react';

const ServicesList = ({ onSelectService, services }) => (
	<ul>
		{services.map(service => (
			<li key={service.id} onClick={() => onSelectService(service)}>
				{service.dates}
			</li>
		))}
	</ul>
);

class ServicesListWrapper extends React.Component {
	render() {
		return <ServicesList {...this.props} />;
	}
}

export default ServicesListWrapper;
