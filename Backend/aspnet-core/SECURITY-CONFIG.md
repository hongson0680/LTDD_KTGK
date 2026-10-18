# Secrets and mobile API configuration

## JWT signing key

The Web Host and Web MVC must use the same key. The source configuration no longer contains a signing key. Generate a random key with at least 32 bytes and store it outside the repository.

For local Development, use the shared User Secrets ID on the Core project:

```powershell
$key = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
dotnet user-secrets set "Authentication:JwtBearer:SecurityKey" $key --project src/2380601916_LeHongSon.Core/2380601916_LeHongSon.Core.csproj
Remove-Variable key
```

For deployed environments, set `Authentication__JwtBearer__SecurityKey` in the secret manager/environment. Use a different random key per environment. Do not commit it. Rotating this key invalidates existing JWTs.

## SQL connection strings

Development uses the local Windows Integrated Authentication connection in `appsettings.json`. Staging and Docker no longer contain the old SQL login. Supply `ConnectionStrings__Default` through the deployment secret store. Docker Compose reads `DB_CONNECTION_STRING` from its environment or an ignored `docker/mvc/.env` file; start from `.env.example` and use a dedicated least-privilege SQL login. Avoid the `sa` account.

## Flutter API URL and TLS

- Android emulator in debug/profile defaults to `http://10.0.2.2:9902`; this reaches the host computer's local development server.
- Flutter Web and desktop default to `http://localhost:9902`.
- Android release builds default to an empty URL; pass the deployed HTTPS origin with `--dart-define=API_BASE_URL=https://api.example.com` or enter it in the connection dialog.
- Physical Android devices should use an HTTPS API endpoint with a certificate trusted by Android. Do not disable certificate validation or trust a self-signed certificate in release. For temporary development, install/trust the development CA on the test device or use an HTTPS tunnel with a publicly trusted certificate.
- Cleartext HTTP is allowed only in Android debug/profile manifests. Release keeps cleartext traffic disabled.

To use Flutter Web with the development backend, run it on the allowed origin, for example:

```powershell
flutter run -d chrome --web-port=5000
```

Add any different web origin explicitly to `App:CorsOrigins` (or `App__CorsOrigins` in the environment). CORS does not secure native mobile requests; use HTTPS and authenticated API calls for deployed clients.
