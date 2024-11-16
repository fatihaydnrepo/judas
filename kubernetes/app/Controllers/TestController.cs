using Microsoft.AspNetCore.Mvc;

namespace DemoApp.Controllers;

[ApiController]
[Route("[controller]")]
public class TestController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<TestController> _logger;

    public TestController(AppDbContext context, ILogger<TestController> logger)
    {
        _context = context;
        _logger = logger;
    }

    [HttpGet]
    public IActionResult Get()
    {
        return Ok(new { message = "API is working!" });
    }

    [HttpGet("db")]
    public IActionResult TestDb()
    {
        try
        {
            _context.Database.CanConnect();
            return Ok(new { message = "Database connection successful!" });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "Database connection failed!", error = ex.Message });
        }
    }
}
