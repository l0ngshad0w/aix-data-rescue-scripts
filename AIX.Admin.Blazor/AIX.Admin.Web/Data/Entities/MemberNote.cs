using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace AIX.Admin.Web.Data.Entities
{
    [Table("member_notes")]
    public class MemberNote
    {
        [Key]
        [Column("note_id")]
        public int NoteId { get; set; }

        [Column("member_no")]
        public int MemberNo { get; set; }

        [Column("note_text")]
        public string NoteText { get; set; } = "";

        [Column("created_dttm")]
        public DateTime CreatedDttm { get; set; }
    }
}