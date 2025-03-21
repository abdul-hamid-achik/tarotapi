namespace :git do
  desc "reset git commit history"
  task :reset do
    puts "this will reset the commit history. all changes will be squashed into a single commit."
    puts "WARNING: this is a destructive operation and cannot be undone!"
    print "are you sure you want to continue? [y/N]: "
    confirmation = STDIN.gets.chomp.downcase

    if confirmation == "y"
      print "enter commit message for the new initial commit: "
      message = STDIN.gets.chomp
      message = "initial commit" if message.empty?

      puts "resetting git history..."

      # Check if there are any uncommitted changes
      has_changes = !`git status --porcelain`.empty?
      if has_changes
        puts "you have uncommitted changes. committing them before proceeding..."
        system("git add .")
        system("git commit -m 'chore: prepare for history reset'")
      end

      # Create a new orphan branch
      current_branch = `git rev-parse --abbrev-ref HEAD`.strip
      temp_branch = "temp-#{Time.now.to_i}"

      system("git checkout --orphan #{temp_branch}") || abort("failed to create orphan branch")
      system("git add .") || abort("failed to add files")
      system("git commit -m '#{message}'") || abort("failed to commit")

      # Replace the current branch with the new one
      system("git branch -D #{current_branch}") || abort("failed to delete old branch")
      system("git branch -m #{current_branch}") || abort("failed to rename branch")

      puts "git history has been reset. you now have a single commit."
      puts "to push this to remote, use:"
      puts "git push -f origin #{current_branch}"
    else
      puts "operation cancelled"
    end
  end

  desc "remove any mentions of pulumi from git history"
  task :clean_pulumi do
    puts "this will search for and remove any mentions of 'pulumi' from the git history."
    puts "WARNING: this rewrites git history and cannot be undone!"
    print "are you sure you want to continue? [y/N]: "
    confirmation = STDIN.gets.chomp.downcase

    if confirmation == "y"
      puts "checking for 'pulumi' in git history..."

      # Check if 'pulumi' exists in git history
      has_pulumi = system("git log -p | grep -i pulumi > /dev/null")

      if has_pulumi
        puts "found 'pulumi' mentions in git history. cleaning..."

        current_branch = `git rev-parse --abbrev-ref HEAD`.strip

        # Use git filter-branch to remove 'pulumi' mentions
        system(%(
          git filter-branch --force --tree-filter '
            find . -type f -not -path "./.git/*" | xargs sed -i "" "s/pulumi/deployment/g"
          ' --prune-empty HEAD
        )) || abort("failed to filter git history")

        puts "git history cleaned. to push changes, use:"
        puts "git push -f origin #{current_branch}"
      else
        puts "no mentions of 'pulumi' found in git history."
      end
    else
      puts "operation cancelled"
    end
  end

  desc "clean up pulumi related files"
  task :cleanup do
    pulumi_files = [
      "infrastructure",
      "Pulumi.yaml",
      "Pulumi.*.yaml"
    ]

    puts "searching for pulumi-related files to remove..."

    pulumi_files.each do |pattern|
      found_files = Dir.glob(pattern)
      if found_files.any?
        puts "found #{found_files.size} files matching pattern: #{pattern}"
        found_files.each do |file|
          if File.directory?(file)
            FileUtils.rm_rf(file)
            puts "removed directory: #{file}"
          else
            File.delete(file)
            puts "removed file: #{file}"
          end
        end
      end
    end

    # Check for pulumi references in other files
    puts "checking for pulumi references in other files..."
    system("grep -r 'pulumi' --include='*.rb' --include='*.yml' --include='*.md' . | grep -v 'git.rake'") do |ok, res|
      if ok
        puts "found references to pulumi in the above files."
        print "would you like to review and clean them? [y/N]: "
        if STDIN.gets.chomp.downcase == "y"
          system("find . -type f -not -path './.git/*' | xargs sed -i '' 's/pulumi/deployment/g'")
          puts "replaced 'pulumi' with 'deployment' in all files"
        end
      else
        puts "no references to pulumi found in code files."
      end
    end

    puts "cleanup complete!"
  end

  desc "create a fresh start for deployment"
  task fresh_start: [ :cleanup, :reset ] do
    puts "fresh start completed!"
    puts "you now have a clean repository with no pulumi references and a fresh git history."
    puts "to push these changes to your remote repository:"
    puts "git push -f origin #{`git rev-parse --abbrev-ref HEAD`.strip}"
  end
end
