# if you're doing anything beyond your local machine, please pin this to a specific version at https://hub.docker.com/_/node/
# FROM node:8-alpine also works here for a smaller image
FROM thegreenhouse/nodejs-dev:0.4.0

# set our node environment, either development or production
# defaults to production, compose overrides this to development on build and run
ARG NODE_ENV=production
ENV NODE_ENV $NODE_ENV

# default to port 8000 for node, and 9229 and 9230 (tests) for debug
ARG PORT=8000
ENV PORT $PORT
EXPOSE $PORT 9229 9230

RUN npm i npm@latest -g

WORKDIR /opt
COPY package.json package-lock.json* ./
RUN npm install && \
    npm install --only=dev && \
    npm cache clean --force
ENV PATH /opt/node_modules/.bin:$PATH

WORKDIR /opt/app
COPY . /opt/app
RUN echo "node_modules" > .eslintignore

RUN npm run build
CMD [ "ws" ]