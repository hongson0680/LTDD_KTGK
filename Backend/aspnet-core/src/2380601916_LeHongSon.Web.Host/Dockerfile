FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /src
COPY ["src/2380601916_LeHongSon.Web.Host/2380601916_LeHongSon.Web.Host.csproj", "src/2380601916_LeHongSon.Web.Host/"]
COPY ["src/2380601916_LeHongSon.Web.Core/2380601916_LeHongSon.Web.Core.csproj", "src/2380601916_LeHongSon.Web.Core/"]
COPY ["src/2380601916_LeHongSon.Application/2380601916_LeHongSon.Application.csproj", "src/2380601916_LeHongSon.Application/"]
COPY ["src/2380601916_LeHongSon.Core/2380601916_LeHongSon.Core.csproj", "src/2380601916_LeHongSon.Core/"]
COPY ["src/2380601916_LeHongSon.EntityFrameworkCore/2380601916_LeHongSon.EntityFrameworkCore.csproj", "src/2380601916_LeHongSon.EntityFrameworkCore/"]
WORKDIR "/src/src/2380601916_LeHongSon.Web.Host"
RUN dotnet restore 

WORKDIR /src
COPY ["src/2380601916_LeHongSon.Web.Host", "src/2380601916_LeHongSon.Web.Host"]
COPY ["src/2380601916_LeHongSon.Web.Core", "src/2380601916_LeHongSon.Web.Core"]
COPY ["src/2380601916_LeHongSon.Application", "src/2380601916_LeHongSon.Application"]
COPY ["src/2380601916_LeHongSon.Core", "src/2380601916_LeHongSon.Core"]
COPY ["src/2380601916_LeHongSon.EntityFrameworkCore", "src/2380601916_LeHongSon.EntityFrameworkCore"]
WORKDIR "/src/src/2380601916_LeHongSon.Web.Host"
RUN dotnet publish -c Release -o /publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0
EXPOSE 80
WORKDIR /app
COPY --from=build /publish .
ENTRYPOINT ["dotnet", "2380601916_LeHongSon.Web.Host.dll"]
