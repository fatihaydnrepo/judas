using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Caching.Distributed;
using System.Text.Json;
using System.Threading.Tasks;

var builder = WebApplication.CreateBuilder(args);

builder.WebHost.ConfigureKestrel(serverOptions =>
{
    serverOptions.ListenAnyIP(8080); // Port belirleniyor
});

// PostgreSQL bağlantısı
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// Redis bağlantısı
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("RedisConnection");
});

// Servisleri ekliyoruz
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();
app.MapControllers();
app.Run();

/// <summary>
/// PostgreSQL ve Redis entegrasyonu için controller
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class TestController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IDistributedCache _cache;

    public TestController(AppDbContext context, IDistributedCache cache)
    {
        _context = context;
        _cache = cache;
    }

    // POST: /api/test/save
    [HttpPost("save")]
    public async Task<IActionResult> SaveData([FromBody] InputModel input)
    {
        // 1. PostgreSQL'e veri kaydetme
        var newData = new MyEntity
        {
            Name = input.Name,
            Age = input.Age
        };
        _context.MyEntities.Add(newData);
        await _context.SaveChangesAsync();

        // 2. Redis'e veri cache olarak yazma
        var cacheKey = $"user:{newData.Id}"; // Redis'te benzersiz anahtar
        var cacheData = JsonSerializer.Serialize(newData);
        await _cache.SetStringAsync(cacheKey, cacheData);

        return Ok(new
        {
            Mesaj = "Veri PostgreSQL'e kaydedildi ve Redis'e cache olarak yazıldı.",
            PostgreSQL = newData,
            RedisKey = cacheKey,
            RedisValue = cacheData
        });
    }

    // GET: /api/test/get/{id}
    [HttpGet("get/{id}")]
    public async Task<IActionResult> GetData(int id)
    {
        // 1. Önce Redis'ten veri çekme
        var cacheKey = $"user:{id}";
        var cachedData = await _cache.GetStringAsync(cacheKey);

        if (!string.IsNullOrEmpty(cachedData))
        {
            var redisResult = JsonSerializer.Deserialize<MyEntity>(cachedData);
            return Ok(new { Mesaj = "Veri Redis'ten alındı.", Veri = redisResult });
        }

        // 2. Redis'te yoksa PostgreSQL'den çekme
        var dbData = await _context.MyEntities.FindAsync(id);
        if (dbData == null)
        {
            return NotFound(new { Mesaj = "Veri bulunamadı." });
        }

        // 3. PostgreSQL'den aldıktan sonra Redis'e yazma
        var newCacheData = JsonSerializer.Serialize(dbData);
        await _cache.SetStringAsync(cacheKey, newCacheData);

        return Ok(new { Mesaj = "Veri PostgreSQL'den alındı ve Redis'e yazıldı.", Veri = dbData });
    }
}

/// <summary>
/// PostgreSQL tablosu için bir model
/// </summary>
public class MyEntity
{
    public int Id { get; set; }
    public string Name { get; set; }
    public int Age { get; set; }
}

/// <summary>
/// Gövde verilerini almak için model
/// </summary>
public class InputModel
{
    public string Name { get; set; }
    public int Age { get; set; }
}

/// <summary>
/// PostgreSQL DbContext
/// </summary>
public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<MyEntity> MyEntities { get; set; }
}
