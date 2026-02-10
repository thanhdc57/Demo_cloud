# Build Stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["DemoCloud.Backend/DemoCloud.Backend.csproj", "DemoCloud.Backend/"]
RUN dotnet restore "DemoCloud.Backend/DemoCloud.Backend.csproj"
COPY . .
WORKDIR "/src/DemoCloud.Backend"
RUN dotnet build "DemoCloud.Backend.csproj" -c Release -o /app/build

# Publish Stage
FROM build AS publish
RUN dotnet publish "DemoCloud.Backend.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Final Stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "DemoCloud.Backend.dll"]
