FROM vapor/swift:5.1
WORKDIR /app
COPY . .
ENTRYPOINT ["swift"]

