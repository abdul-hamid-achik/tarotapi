namespace :usage do
  desc "Reset all reading quotas for users at the start of a new billing period"
  task reset_quotas: :environment do
    total = 0
    reset = 0

    ReadingQuota.find_each do |quota|
      total += 1
      if quota.should_reset?
        quota.reset!
        reset += 1

        # Notify user if configured
        UsageMailer.quota_reset(quota.user).deliver_later if defined?(UsageMailer)
      end
    end

    puts "Processed #{total} quotas, reset #{reset}"
  end

  desc "Archive old usage logs (older than 90 days by default)"
  task :archive_logs, [ :days ] => :environment do |t, args|
    days = args[:days] ? args[:days].to_i : 90
    cutoff_date = days.days.ago

    log_count = UsageLog.where("created_at < ?", cutoff_date).count

    if log_count > 0
      # Archive to S3 or other storage if configured
      if defined?(UsageArchiveService)
        UsageArchiveService.archive_logs_before(cutoff_date)
      end

      # Delete old logs
      deleted = UsageLog.where("created_at < ?", cutoff_date).delete_all
      puts "Deleted #{deleted} usage logs older than #{days} days"
    else
      puts "No usage logs found older than #{days} days"
    end
  end

  desc "Generate usage analytics for all organizations"
  task generate_analytics: :environment do
    Organization.find_each do |org|
      puts "Generating analytics for #{org.name}"

      # Generate daily metrics for the past 30 days
      end_date = Time.current
      start_date = 30.days.ago

      # Get basic metrics
      logs = UsageLog.where(
        organization_id: org.id,
        recorded_at: start_date..end_date
      )

      daily_metrics = logs.group("date_trunc('day', recorded_at)")
                        .group(:metric_type)
                        .count

      api_calls = logs.api_calls.count
      readings = logs.readings.count
      avg_response_time = logs.api_calls.average("(metadata->>'response_time')::float")
      error_rate = UsageLog.error_rate(start_date, end_date)

      puts "  API Calls: #{api_calls}"
      puts "  Readings: #{readings}"
      puts "  Avg Response Time: #{avg_response_time.to_f.round(2)}ms"
      puts "  Error Rate: #{error_rate}%"

      # Calculate unique users
      unique_users = logs.where.not(user_id: nil).select(:user_id).distinct.count
      puts "  Unique Users: #{unique_users}"

      # Store analytics if configured
      if defined?(OrganizationAnalytics)
        OrganizationAnalytics.create!(
          organization: org,
          period_start: start_date,
          period_end: end_date,
          api_calls: api_calls,
          readings: readings,
          unique_users: unique_users,
          average_response_time: avg_response_time,
          error_rate: error_rate
        )
      end
    end
  end

  desc "Alert on usage anomalies"
  task anomaly_detection: :environment do
    # Define thresholds
    error_threshold = 5.0 # 5% error rate
    response_time_threshold = 500 # 500ms
    usage_spike_threshold = 3.0 # 3x normal usage

    Organization.find_each do |org|
      # Compare today with average of last 7 days
      today = Time.current.beginning_of_day
      yesterday = 1.day.ago.beginning_of_day
      last_week_start = 8.days.ago.beginning_of_day

      # Get today's metrics
      today_logs = UsageLog.where(
        organization_id: org.id,
        recorded_at: today..Time.current
      )

      today_count = today_logs.count
      today_errors = today_logs.api_calls.failed.count
      today_error_rate = today_count > 0 ? (today_errors.to_f / today_count * 100) : 0
      today_response_time = today_logs.api_calls.average("(metadata->>'response_time')::float")

      # Get historical average
      historical_logs = UsageLog.where(
        organization_id: org.id,
        recorded_at: last_week_start..yesterday
      )

      # Group by day to get average per day
      historical_daily = historical_logs.group("date_trunc('day', recorded_at)").count
      historical_avg = historical_daily.values.sum / historical_daily.size.to_f

      # Check for anomalies
      if today_error_rate > error_threshold
        puts "ERROR RATE ALERT: #{org.name} has error rate of #{today_error_rate.round(2)}%"
        # Send alert if configured
        AdminMailer.error_rate_alert(org, today_error_rate).deliver_later if defined?(AdminMailer)
      end

      if today_response_time && today_response_time > response_time_threshold
        puts "RESPONSE TIME ALERT: #{org.name} has average response time of #{today_response_time.to_f.round(2)}ms"
        # Send alert if configured
        AdminMailer.response_time_alert(org, today_response_time).deliver_later if defined?(AdminMailer)
      end

      if historical_avg > 0 && (today_count / historical_avg) > usage_spike_threshold
        puts "USAGE SPIKE ALERT: #{org.name} has #{today_count} requests today (#{(today_count / historical_avg).round(2)}x normal)"
        # Send alert if configured
        AdminMailer.usage_spike_alert(org, today_count, historical_avg).deliver_later if defined?(AdminMailer)
      end
    end
  end
end

# Add a scheduled task to run daily
Rake::Task["usage:reset_quotas"].enhance do
  puts "Finished resetting quotas at #{Time.current}"
end
