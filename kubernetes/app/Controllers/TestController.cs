[ApiController]
[Route("api/[controller]")]
public class TestController : ControllerBase
{
    private readonly AppDbContext _context;

    public TestController(AppDbContext context)
    {
        _context = context;
    }

    // POST: /api/test/save
    [HttpPost("save")]
    public IActionResult SaveData([FromBody] InputModel input)
    {
        if (input == null)
        {
            return BadRequest(new { Mesaj = "Geçersiz veri." });
        }

        // Veriyi PostgreSQL'e kaydetme
        var newEntity = new MyEntity
        {
            Name = input.Name,
            Age = input.Age
        };

        _context.MyEntities.Add(newEntity);
        _context.SaveChanges();

        return Ok(new { Mesaj = "Veri başarıyla kaydedildi.", Veri = newEntity });
    }
}
