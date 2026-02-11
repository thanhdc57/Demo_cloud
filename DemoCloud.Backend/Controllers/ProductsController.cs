using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DemoCloud.Backend.Data;
using DemoCloud.Backend.Models;

namespace DemoCloud.Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly AppDbContext _context;

    public ProductsController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResult<Product>>> GetProducts(
        string? search, 
        string? sortColumn, 
        string? sortOrder, 
        int page = 1, 
        int pageSize = 10)
    {
        var query = _context.Products.AsQueryable();

        // 1. Filtering
        if (!string.IsNullOrWhiteSpace(search))
        {
            search = search.ToLower();
            query = query.Where(p => p.Name.ToLower().Contains(search) || 
                                     p.Description.ToLower().Contains(search));
        }

        // 2. Sorting
        // Simple manual sort to avoid adding external dependencies like System.Linq.Dynamic.Core for now
        if (sortOrder?.ToLower() == "desc")
        {
            query = sortColumn?.ToLower() switch
            {
                "price" => query.OrderByDescending(p => p.Price),
                "name" => query.OrderByDescending(p => p.Name),
                _ => query.OrderByDescending(p => p.Id)
            };
        }
        else
        {
            query = sortColumn?.ToLower() switch
            {
                "price" => query.OrderBy(p => p.Price),
                "name" => query.OrderBy(p => p.Name),
                _ => query.OrderBy(p => p.Id)
            };
        }

        // 3. Paging
        var totalCount = await query.CountAsync();
        var items = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();

        return new PagedResult<Product>
        {
            Items = items,
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Product>> GetProduct(int id)
    {
        var product = await _context.Products.FindAsync(id);

        if (product == null)
        {
            return NotFound();
        }

        return product;
    }

    [HttpPost]
    public async Task<ActionResult<Product>> PostProduct(Product product)
    {
        _context.Products.Add(product);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetProduct), new { id = product.Id }, product);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> PutProduct(int id, Product product)
    {
        if (id != product.Id)
        {
            return BadRequest();
        }

        _context.Entry(product).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!ProductExists(id))
            {
                return NotFound();
            }
            else
            {
                throw;
            }
        }

        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteProduct(int id)
    {
        var product = await _context.Products.FindAsync(id);
        if (product == null)
        {
            return NotFound();
        }

        _context.Products.Remove(product);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    private bool ProductExists(int id)
    {
        return _context.Products.Any(e => e.Id == id);
    }
}
