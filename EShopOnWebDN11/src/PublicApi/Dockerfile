#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:11.0 AS base
WORKDIR /app
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:11.0 AS build
ARG NUGET_SOURCE=https://api.nuget.org/v3/index.json
WORKDIR /app
COPY . .
#COPY ["src/PublicApi/PublicApi.csproj", "./PublicApi/"]
#RUN dotnet restore "./PublicApi/PublicApi.csproj"
#COPY . .
WORKDIR "/app/src/PublicApi"
RUN dotnet restore --source "$NUGET_SOURCE" -p:Configuration=Release

RUN dotnet build "./PublicApi.csproj" -c Release --no-restore -o /app/build

FROM build AS publish
RUN dotnet publish "./PublicApi.csproj" -c Release --no-restore -p:UseAppHost=false -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "PublicApi.dll"]