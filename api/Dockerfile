# Build context: ./api
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY Toni.Api/Toni.Api.csproj Toni.Api/
RUN dotnet restore Toni.Api/Toni.Api.csproj
COPY Toni.Api/ Toni.Api/
RUN dotnet publish Toni.Api/Toni.Api.csproj -c Release -o /out --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /out .
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
USER $APP_UID
ENTRYPOINT ["dotnet", "Toni.Api.dll"]
