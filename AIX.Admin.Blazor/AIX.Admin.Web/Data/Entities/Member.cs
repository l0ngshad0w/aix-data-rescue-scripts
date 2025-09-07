namespace AIX.Admin.Web.Data.Entities;

public class Member
{
    public int Id { get; set; }

    public string MemberNumber { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;

    public string? Address1 { get; set; }
    public string? Address2 { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? PostalCode { get; set; }

    public DateTime? BirthDate { get; set; }

    public string? Phone { get; set; }
    public string? Email { get; set; }

    public string? Status { get; set; }           // e.g., Active, Inactive
    public DateTime? JoinDate { get; set; }
    public DateTime? ExpireDate { get; set; }

    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedUtc { get; set; }
}
