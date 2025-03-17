require 'factory_bot'

World(FactoryBot::Syntax::Methods)

FactoryBot.definition_file_paths = ['spec/factories']

Before do
  FactoryBot.reload
end 