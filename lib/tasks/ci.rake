namespace :ci do
  desc "Build the CI Docker image"
  task :build_image do
    sh "docker build -t tarot-api-ci:latest -f Dockerfile.ci --target ci ."
  end

  desc "Run linting locally with act"
  task :lint => :build_image do
    sh "act -j lint -W .github/workflows/ci.yml"
  end

  desc "Run tests locally with act"
  task :test => :build_image do
    sh "act -j test -W .github/workflows/ci.yml"
  end

  desc "Generate API docs locally with act"
  task :docs => :build_image do
    sh "act -j docs -W .github/workflows/ci.yml"
  end

  desc "Run all CI jobs locally"
  task :all => :build_image do
    sh "act -W .github/workflows/ci.yml"
  end
end

desc "Run all CI locally (alias for ci:all)"
task :ci => "ci:all" 