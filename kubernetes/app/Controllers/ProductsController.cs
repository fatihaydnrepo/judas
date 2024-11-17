using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DemoApp.Models;
using DemoApp.Data;
using System.Text.Json;
using StackExchange.Redis;

namespace DemoApp.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<ProductsController> _logger;
    private readonly IConnectionMultiplexer _redis;

    public ProductsController(
        AppDbContext context, 
        ILogger<ProductsController> logger,
        IConnectionMultiplexer redis)
    {
        _context = context;
        _logger = logger;
        _redis = redis;
    }

    // Orijinal endpoint'ler
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Product>>> GetProducts()
    {
        try
        {
            return await _context.Products.ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting products");
            return StatusCode(500, new { message = ex.Message, details = ex.InnerException?.Message });
        }
    }

    [HttpPost]
    public async Task<ActionResult<Product>> CreateProduct(Product product)
    {
        try
        {
            _context.Products.Add(product);
            await _context.SaveChangesAsync();
            return CreatedAtAction(nameof(GetProducts), new { id = product.Id }, product);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating product. Product details: {@Product}", product);
            return StatusCode(500, new { message = ex.Message, details = ex.InnerException?.Message });
        }
    }

    // Redis cache'li endpoint'ler
    [HttpGet("cached")]
    public async Task<ActionResult<IEnumerable<Product>>> GetProductsCached()
    {
        try
        {
            var db = _redis.GetDatabase();
            var cacheKey = "all_products";
            var cached = await db.StringGetAsync(cacheKey);

            if (!cached.IsNull)
            {
                _logger.LogInformation("Returning products from cache");
                return Ok(JsonSerializer.Deserialize<List<Product>>(cached));
            }

            var products = await _context.Products.ToListAsync();
            await db.StringSetAsync(cacheKey, JsonSerializer.Serialize(products), TimeSpan.FromMinutes(5));
            
            return Ok(products);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting cached products");
            return StatusCode(500, new { message = ex.Message, details = ex.InnerException?.Message });
        }
    }

    [HttpPost("withCache")]
    public async Task<ActionResult<Product>> CreateProductWithCache(Product product)
    {
        try
        {
            _context.Products.Add(product);
            await _context.SaveChangesAsync();

            // Redis cache'i temizle
            var db = _redis.GetDatabase();
            await db.KeyDeleteAsync("all_products");

            return CreatedAtAction(nameof(GetProducts), new { id = product.Id }, product);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating product with cache. Product details: {@Product}", product);
            return StatusCode(500, new { message = ex.Message, details = ex.InnerException?.Message });
        }
    }

    // Direkt DB erişimli endpoint
    [HttpPost("directDb")]
    public async Task<ActionResult<Product>> CreateProductDirectDb(Product product)
    {
        try
        {
            await _context.Database.ExecuteSqlRawAsync(@"
                INSERT INTO ""Products"" (""Name"", ""Price"") 
                VALUES ({0}, {1}) 
                RETURNING *", 
                product.Name, product.Price);

            return CreatedAtAction(nameof(GetProducts), new { id = product.Id }, product);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating product with direct DB access. Product details: {@Product}", product);
            return StatusCode(500, new { message = ex.Message, details = ex.InnerException?.Message });
        }
    }
}
