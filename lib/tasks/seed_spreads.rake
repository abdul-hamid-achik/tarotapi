namespace :spreads do
  desc 'seed system spreads'
  task seed: :environment do
    puts 'seeding system spreads...'
    SpreadService.system_spreads
    puts "created #{Spread.system_spreads.count} system spreads"
  end
end 