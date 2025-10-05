namespace AIX.Admin.Web.Data.Entities;

public class Member
{
    // PK (not identity)
    public int MemberNo { get; set; }

    public int? ZipCode { get; set; }
    public short? ZipExt { get; set; }

    public string? LastName { get; set; }
    public string? FirstName { get; set; }
    public string? MiddleName { get; set; }

    public string? Address { get; set; }
    public string? CityState { get; set; }

    public short? SameAdr { get; set; }   // stored as SMALLINT (0/1 typically)

    public int? CongrNum { get; set; }
    public int? CongrNum2 { get; set; }

    public DateTime? OrdinDate { get; set; }
    public DateTime? SubscrDate { get; set; }

    public string? AreaCode { get; set; }     // varchar(10)
    public string? PhoneNo { get; set; }      // varchar(20)
    public string? EmailAdr { get; set; }     // varchar(120)

    // Optional bookkeeping
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedUtc { get; set; }
}
