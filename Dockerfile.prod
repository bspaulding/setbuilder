FROM node:carbon as builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run webpack:prod

FROM node:carbon
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/dist ./dist
COPY package.json .
EXPOSE 80
CMD npm start
