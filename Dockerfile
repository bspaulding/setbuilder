FROM node:carbon as builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY elm.json elm.json
COPY webpack.config.*.js ./
COPY src src
RUN npm run build

FROM node:carbon
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/dist ./dist
COPY package.json .
EXPOSE 80
ENV PCO_CLIENT_ID
ENV PCO_CLIENT_SECRET
ENV SPOTIFY_CLIENT_ID
ENV SPOTIFY_CLIENT_SECRET
ENV USE_SSL false
ENV CALLBACK_ENV https://localhost:3000
CMD npm start
