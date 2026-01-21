FROM node:14.17.0

WORKDIR /app

# Intentionally vulnerable package.json
COPY package.json .
RUN npm install

COPY app.js .

EXPOSE 3000

CMD ["node", "app.js"]
