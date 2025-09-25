FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish -c Release -o /out
FROM nginx:1.27-alpine
COPY --from=build /out/wwwroot /usr/share/nginx/html
EXPOSE 80
