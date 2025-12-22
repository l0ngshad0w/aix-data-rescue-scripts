namespace AIX.Admin.Web.Data.Entities
{
    public class CourseTitle
    {
        public char CtType { get; set; }
        public short CtNumber { get; set; }

        public string? Desc1 { get; set; }
        public string? Desc2 { get; set; }

        //Navigation Properties
        public ICollection<MemberCourse> MemberCourses { get; set; } = new List<MemberCourse>();
    }
}
