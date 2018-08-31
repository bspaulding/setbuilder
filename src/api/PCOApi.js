import https from 'https';

const flatMap = (xs, f) => {
	return xs.reduce((acc, x) => {
		return acc.concat(f(x));
	}, []);
};

export const getUserInfo = ({ headers }) =>
	new Promise(resolve => {
		https.get(
			{
				hostname: 'api.planningcenteronline.com',
				path: '/people/v2/me',
				headers
			},
			response => {
				var body = '';
				response.on('data', data => {
					body += data.toString('utf8');
				});
				response.on('end', () => {
					resolve(JSON.parse(body));
				});
			}
		);
	});

export const getPlanItems = ({ headers, serviceTypeId, planId }) =>
	new Promise(resolve => {
		https.get(
			{
				hostname: 'api.planningcenteronline.com',
				path: `/services/v2/service_types/${serviceTypeId}/plans/${planId}/items?include=song`,
				headers
			},
			itemsResponse => {
				var body = '';
				itemsResponse.on('data', data => {
					body += data.toString('utf8');
				});
				itemsResponse.on('end', () => {
					resolve(JSON.parse(body));
				});
			}
		);
	});

export const getPlanSongs = async ({ headers, serviceTypeId, planId }) => {
	const items = await getPlanItems({ headers, serviceTypeId, planId });
	return items.data.filter(item => item.attributes.item_type === 'song');
};

export const getAllPlans = ({ headers }) =>
	new Promise(resolve => {
		https.get(
			{
				hostname: 'api.planningcenteronline.com',
				path: '/services/v2/service_types',
				headers
			},
			typesResponse => {
				typesResponse.on('data', async data => {
					const serviceTypes = JSON.parse(data.toString('utf8'));
					const plans$ = await Promise.all(
						serviceTypes.data.map(
							type =>
								new Promise(resolve => {
									https.get(
										{
											hostname: 'api.planningcenteronline.com',
											path: `/services/v2/service_types/${type.id}/plans`,
											headers
										},
										plansResponse => {
											plansResponse.on('data', async data => {
												const plans = JSON.parse(data.toString('utf8'));
												resolve(plans.data);
											});
										}
									);
								})
						)
					);
					const plans = flatMap(plans$, plans => plans);
					resolve(plans);
				});
			}
		);
	});

export const getAllPlansWithItems = ({ headers }) =>
	new Promise(resolve => {
		https.get(
			{
				hostname: 'api.planningcenteronline.com',
				path: '/services/v2/service_types',
				headers
			},
			typesResponse => {
				typesResponse.on('data', async data => {
					const serviceTypes = JSON.parse(data.toString('utf8'));
					const plans$ = await Promise.all(
						serviceTypes.data.map(
							type =>
								new Promise(resolve => {
									https.get(
										{
											hostname: 'api.planningcenteronline.com',
											path: `/services/v2/service_types/${type.id}/plans`,
											headers
										},
										plansResponse => {
											plansResponse.on('data', async data => {
												const plans = JSON.parse(data.toString('utf8'));
												const items = await Promise.all(
													plans.data.map(plan =>
														getPlanItems({
															headers,
															serviceTypeId: type.id,
															planId: plan.id
														})
													)
												);
												resolve(
													plans.data.map((plan, i) => ({
														...plan,
														items: items[i]
													}))
												);
											});
										}
									);
								})
						)
					);
					const plans = flatMap(plans$, plans => plans);
					resolve(plans);
				});
			}
		);
	});
