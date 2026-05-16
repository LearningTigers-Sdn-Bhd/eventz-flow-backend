require 'csv'

namespace :email_delivery do
  desc 'Backfill email deliveries from a Resend CSV export. Usage: CSV_PATH=/path/to/resend.csv rails email_delivery:backfill_csv'
  task backfill_csv: :environment do
    csv_path = ENV.fetch('CSV_PATH')
    rows = CSV.read(csv_path, headers: true).map(&:to_h)
    EmailDelivery::HistoricalBackfill.call(rows)
    puts "Imported Resend email rows from #{csv_path}"
  end
end
