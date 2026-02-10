# Build Stage
FROM node:18-alpine as build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Serve Stage
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
# Copy config as template
COPY nginx.conf /etc/nginx/conf.d/default.conf.template
EXPOSE 80

# Environment variable for Backend Host, default to demo-backend (VM DNS name)
ENV BACKEND_HOST=demo-backend

# Entrypoint to run envsubst
CMD ["/bin/sh", "-c", "envsubst '${BACKEND_HOST}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
