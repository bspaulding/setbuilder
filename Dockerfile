FROM node:carbon as builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY elm.json elm.json
COPY webpack.config.*.js ./
COPY .env .env
COPY src src
RUN npm run build

FROM node:carbon
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/dist ./dist
COPY package.json .
EXPOSE 80
CMD npm start
