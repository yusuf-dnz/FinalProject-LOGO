#Build aşaması
FROM node:14 AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

#Run aşaması
FROM nginx:1.19.0-alpine AS run
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80 80
CMD ["nginx", "-g", "daemon off;"]