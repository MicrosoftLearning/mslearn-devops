# Build with the published ChatApi folder as context, not the source root.
FROM mcr.microsoft.com/dotnet/aspnet:11.0
WORKDIR /app
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
COPY . .
USER $APP_UID
ENTRYPOINT ["dotnet", "ChatApi.dll"]
