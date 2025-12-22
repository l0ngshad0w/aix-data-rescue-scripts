namespace AIX.Admin.Web.Data.Entities;

public class Member
{
    public int MemberPkId { get; set; }          // identity PK
    public int MemberNo { get; set; }            // business key

    public int? ZipCode { get; set; }
    public short? ZipExt { get; set; }

    public string? LastName { get; set; }
    public string? FirstName { get; set; }
    public string? MiddleName { get; set; }

    public string? Address1 { get; set; }
    public string? Address2 { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? ForeignAddress { get; set; }

    public short? SameAdr { get; set; }

    public int? CongrNum { get; set; }
    public int? CongrNum2 { get; set; }

    public DateOnly? OrdinDate { get; set; }
    public DateOnly? SubscrDate { get; set; }

    public string? AreaCode { get; set; }
    public string? PhoneNo { get; set; }
    public string? EmailAdr { get; set; }

    public DateTime LastModifiedDttm { get; set; }   // maintained by DB default
}
