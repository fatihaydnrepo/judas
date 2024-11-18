using Microsoft.EntityFrameworkCore;
using DemoApp.Data;
using StackExchange.Redis;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.ConfigureKestrel(serverOptions => { serverOptions.ListenAnyIP(8080); });
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// PostgreSQL bağlantısı
var postgresBuilder = new NpgsqlConnectionStringBuilder
{
    Host = Environment.GetEnvironmentVariable("POSTGRES_HOST") ?? "postgres-postgresql.demo.svc.cluster.local",
    Port = int.Parse(Environment.GetEnvironmentVariable("POSTGRES_PORT") ?? "5432"),
    Database = Environment.GetEnvironmentVariable("POSTGRES_DB") ?? "containers",
    Username = Environment.GetEnvironmentVariable("POSTGRES_USER") ?? "postgres",
    Password = Environment.GetEnvironmentVariable("POSTGRES_PASSWORD"),
    IncludeErrorDetail = true  // Hata detaylarını görmek için ekledik
};

builder.Services.AddDbContext<AppDbContext>(options => 
    options.UseNpgsql(postgresBuilder.ConnectionString));

// Redis bağlantısı
var redisHost = Environment.GetEnvironmentVariable("REDIS_HOST") ?? "redis-master.demo.svc.cluster.local";
var redisPort = Environment.GetEnvironmentVariable("REDIS_PORT") ?? "6379";
var redisConfigurationOptions = new ConfigurationOptions
{
    EndPoints = { $"{redisHost}:{redisPort}" },
    Password = Environment.GetEnvironmentVariable("REDIS_PASSWORD"),
    AbortOnConnectFail = false
};

builder.Services.AddSingleton<IConnectionMultiplexer>(
    ConnectionMultiplexer.Connect(redisConfigurationOptions));

var app = builder.Build();

// Database initialization
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    try
    {
        await context.Database.EnsureCreatedAsync();
        logger.LogInformation("Database initialized successfully");
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Database initialization failed");
        throw;
    }
}

app.UseSwagger();
app.UseSwaggerUI();
app.MapControllers();
app.Run();
