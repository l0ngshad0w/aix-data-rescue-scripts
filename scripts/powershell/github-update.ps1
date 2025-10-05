git init
git config user.name "Your Name"
git config user.email "you@example.com"

# Good .gitignore for .NET
dotnet new gitignore

git add .
git commit -m "chore: bootstrap Blazor Server + EF Core + IIS publish profile"

# Create an empty repo on GitHub named churchapp (private).
# Then set the remote and push:
git branch -M main
git remote add origin https://github.com/<your-username>/churchapp.git
git push -u origin main
