namespace AIX.Admin.Web.Data.Entities
{
    public class MemberCourse
    {
        public int MemberNo { get; set; }
        public char CtType { get; set; }
        public short CtNumber { get; set; }

        public DateOnly? AssignedDate { get; set; }

        //Navigation Properties
        public Member? Member { get; set; }
        public CourseTitle? CourseTitle { get; set; }  
    }
}
