# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

# Set environment variables to optimize dotnet restore
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
ENV DOTNET_CLI_HOME=/tmp

# Set working directory
WORKDIR /src

# Copy only the project file first
COPY *.csproj .

# Restore packages with specific options
RUN dotnet restore --disable-parallel

# Install EF Core tools
RUN dotnet tool install --global dotnet-ef

# Copy everything else and build
COPY . .
RUN dotnet publish -c Release -o /app

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "app.dll"]
