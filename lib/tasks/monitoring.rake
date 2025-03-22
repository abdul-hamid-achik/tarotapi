namespace :monitoring do
  desc "set up monitoring for kamal deployments"
  task :setup do
    puts "setting up monitoring for kamal deployments..."

    # Check if deploy.yml exists
    unless File.exist?("config/deploy.yml")
      abort "config/deploy.yml not found. run 'bundle exec rake kamal:init' first"
    end

    # Create monitoring directory
    monitoring_dir = "config/monitoring"
    FileUtils.mkdir_p(monitoring_dir)

    # Create prometheus config
    prometheus_config = <<~YAML
      global:
        scrape_interval: 15s
        evaluation_interval: 15s

      scrape_configs:
        - job_name: 'prometheus'
          static_configs:
            - targets: ['localhost:9090']
      #{'  '}
        - job_name: 'tarot-api'
          scrape_interval: 5s
          metrics_path: /metrics
          static_configs:
            - targets: ['tarot_api:3000']
      #{'  '}
        - job_name: 'postgres'
          static_configs:
            - targets: ['postgres-exporter:9187']
      #{'  '}
        - job_name: 'redis'
          static_configs:
            - targets: ['redis-exporter:9121']
      #{'  '}
        - job_name: 'cadvisor'
          static_configs:
            - targets: ['cadvisor:8080']
      #{'  '}
        - job_name: 'node-exporter'
          static_configs:
            - targets: ['node-exporter:9100']
    YAML

    # Create grafana dashboard
    grafana_dashboard = <<~JSON
      {
        "annotations": {
          "list": [
            {
              "builtIn": 1,
              "datasource": "-- Grafana --",
              "enable": true,
              "hide": true,
              "iconColor": "rgba(0, 211, 255, 1)",
              "name": "Annotations & Alerts",
              "type": "dashboard"
            }
          ]
        },
        "editable": true,
        "gnetId": null,
        "graphTooltip": 0,
        "id": 1,
        "links": [],
        "panels": [
          {
            "aliasColors": {},
            "bars": false,
            "dashLength": 10,
            "dashes": false,
            "datasource": "Prometheus",
            "fill": 1,
            "fillGradient": 0,
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 0,
              "y": 0
            },
            "hiddenSeries": false,
            "id": 2,
            "legend": {
              "avg": false,
              "current": false,
              "max": false,
              "min": false,
              "show": true,
              "total": false,
              "values": false
            },
            "lines": true,
            "linewidth": 1,
            "nullPointMode": "null",
            "options": {
              "dataLinks": []
            },
            "percentage": false,
            "pointradius": 2,
            "points": false,
            "renderer": "flot",
            "seriesOverrides": [],
            "spaceLength": 10,
            "stack": false,
            "steppedLine": false,
            "targets": [
              {
                "expr": "http_server_requests_seconds_count",
                "legendFormat": "{{method}} {{uri}}",
                "refId": "A"
              }
            ],
            "thresholds": [],
            "timeFrom": null,
            "timeRegions": [],
            "timeShift": null,
            "title": "HTTP Requests",
            "tooltip": {
              "shared": true,
              "sort": 0,
              "value_type": "individual"
            },
            "type": "graph",
            "xaxis": {
              "buckets": null,
              "mode": "time",
              "name": null,
              "show": true,
              "values": []
            },
            "yaxes": [
              {
                "format": "short",
                "label": null,
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              },
              {
                "format": "short",
                "label": null,
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              }
            ],
            "yaxis": {
              "align": false,
              "alignLevel": null
            }
          },
          {
            "aliasColors": {},
            "bars": false,
            "dashLength": 10,
            "dashes": false,
            "datasource": "Prometheus",
            "fill": 1,
            "fillGradient": 0,
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 12,
              "y": 0
            },
            "hiddenSeries": false,
            "id": 4,
            "legend": {
              "avg": false,
              "current": false,
              "max": false,
              "min": false,
              "show": true,
              "total": false,
              "values": false
            },
            "lines": true,
            "linewidth": 1,
            "nullPointMode": "null",
            "options": {
              "dataLinks": []
            },
            "percentage": false,
            "pointradius": 2,
            "points": false,
            "renderer": "flot",
            "seriesOverrides": [],
            "spaceLength": 10,
            "stack": false,
            "steppedLine": false,
            "targets": [
              {
                "expr": "http_server_requests_seconds_sum / http_server_requests_seconds_count",
                "legendFormat": "{{method}} {{uri}}",
                "refId": "A"
              }
            ],
            "thresholds": [],
            "timeFrom": null,
            "timeRegions": [],
            "timeShift": null,
            "title": "Response Time",
            "tooltip": {
              "shared": true,
              "sort": 0,
              "value_type": "individual"
            },
            "type": "graph",
            "xaxis": {
              "buckets": null,
              "mode": "time",
              "name": null,
              "show": true,
              "values": []
            },
            "yaxes": [
              {
                "format": "s",
                "label": null,
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              },
              {
                "format": "short",
                "label": null,
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              }
            ],
            "yaxis": {
              "align": false,
              "alignLevel": null
            }
          }
        ],
        "refresh": "5s",
        "schemaVersion": 22,
        "style": "dark",
        "tags": [],
        "templating": {
          "list": []
        },
        "time": {
          "from": "now-30m",
          "to": "now"
        },
        "timepicker": {},
        "timezone": "",
        "title": "Tarot API Dashboard",
        "uid": "tarot-api",
        "version": 1
      }
    JSON

    # Create docker-compose for monitoring stack
    docker_compose = <<~YAML
      version: '3.8'

      services:
        prometheus:
          image: prom/prometheus:v2.47.0
          container_name: prometheus
          volumes:
            - ./prometheus.yml:/etc/prometheus/prometheus.yml
            - prometheus_data:/prometheus
          command:
            - '--config.file=/etc/prometheus/prometheus.yml'
            - '--storage.tsdb.path=/prometheus'
            - '--web.console.libraries=/usr/share/prometheus/console_libraries'
            - '--web.console.templates=/usr/share/prometheus/consoles'
          ports:
            - "9090:9090"
          networks:
            - monitoring

        grafana:
          image: grafana/grafana:10.0.3
          container_name: grafana
          ports:
            - "3000:3000"
          volumes:
            - grafana_data:/var/lib/grafana
            - ./dashboards:/var/lib/grafana/dashboards
          environment:
            - GF_SECURITY_ADMIN_USER=admin
            - GF_SECURITY_ADMIN_PASSWORD=admin
            - GF_USERS_ALLOW_SIGN_UP=false
          networks:
            - monitoring

        postgres-exporter:
          image: prometheuscommunity/postgres-exporter:v0.14.0
          container_name: postgres-exporter
          environment:
            - DATA_SOURCE_NAME=postgresql://postgres:password@db:5432/postgres?sslmode=disable
          ports:
            - "9187:9187"
          networks:
            - monitoring
            - default
          depends_on:
            - prometheus

        redis-exporter:
          image: oliver006/redis_exporter:v1.55.0
          container_name: redis-exporter
          environment:
            - REDIS_ADDR=redis://redis:6379
          ports:
            - "9121:9121"
          networks:
            - monitoring
            - default
          depends_on:
            - prometheus

        cadvisor:
          image: gcr.io/cadvisor/cadvisor:v0.47.2
          container_name: cadvisor
          volumes:
            - /:/rootfs:ro
            - /var/run:/var/run:ro
            - /sys:/sys:ro
            - /var/lib/docker/:/var/lib/docker:ro
            - /dev/disk/:/dev/disk:ro
          ports:
            - "8080:8080"
          privileged: true
          networks:
            - monitoring

        node-exporter:
          image: prom/node-exporter:v1.6.1
          container_name: node-exporter
          volumes:
            - /proc:/host/proc:ro
            - /sys:/host/sys:ro
            - /:/rootfs:ro
          command:
            - '--path.procfs=/host/proc'
            - '--path.sysfs=/host/sys'
            - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
          ports:
            - "9100:9100"
          networks:
            - monitoring

      volumes:
        prometheus_data:
        grafana_data:

      networks:
        monitoring:
        default:
          external:
            name: tarot_api_default
    YAML

    # Write configuration files
    File.write("#{monitoring_dir}/prometheus.yml", prometheus_config)
    File.write("#{monitoring_dir}/tarot-api-dashboard.json", grafana_dashboard)
    File.write("#{monitoring_dir}/docker-compose.yml", docker_compose)

    # Create dashboard directory
    FileUtils.mkdir_p("#{monitoring_dir}/dashboards")

    # Update deploy.yml to include monitoring
    update_deploy_yml = <<~BASH
      #!/bin/bash
      sed -i '' -e '/traefik:/i\\
      # monitoring configuration\\
      healthcheck:\\
        path: /health\\
        port: 3000\\
        interval: 10s\\
        timeout: 5s\\
        retries: 5\\
      \\
      ' config/deploy.yml
    BASH

    # Make the script executable
    File.write("#{monitoring_dir}/update_deploy.sh", update_deploy_yml)
    FileUtils.chmod(0755, "#{monitoring_dir}/update_deploy.sh")

    puts "monitoring configuration created in #{monitoring_dir}"
    puts "\nnext steps:"
    puts "1. review configuration files in #{monitoring_dir}"
    puts "2. run '#{monitoring_dir}/update_deploy.sh' to update deploy.yml"
    puts "3. deploy monitoring with 'bundle exec rake monitoring:deploy'"

    # Create documentation
    monitoring_docs = <<~MD
      # Monitoring Setup for Tarot API

      This directory contains monitoring configuration for the Tarot API using Prometheus and Grafana.

      ## Components

      - **Prometheus**: Time-series database for metrics
      - **Grafana**: Visualization and dashboarding
      - **Exporters**:
        - Postgres Exporter: Database metrics
        - Redis Exporter: Cache metrics
        - cAdvisor: Container metrics
        - Node Exporter: Host metrics

      ## Setup

      1. Deploy the Tarot API using Kamal
      2. Deploy the monitoring stack:

         ```bash
         bundle exec rake monitoring:deploy
         ```

      3. Access Grafana at http://your-server:3000
         - Username: admin
         - Password: admin (change this in production)

      4. Add Prometheus as a data source:
         - URL: http://prometheus:9090
         - Access: Server

      5. Import dashboards from the dashboards directory

      ## Metrics

      The Tarot API exposes metrics at `/metrics` endpoint. These include:

      - HTTP request count and duration
      - Database query performance
      - Memory and CPU usage
      - Cache hit/miss rates
      - Custom business metrics

      ## Alerting

      Configure alerting in Grafana for:

      - High response times (> 500ms)
      - Error rates > 1%
      - Memory usage > 80%
      - Database connection pool saturation

      ## References

      - [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
      - [Grafana Documentation](https://grafana.com/docs/)
      - [Rails Prometheus Client](https://github.com/prometheus/client_ruby)
    MD

    File.write("#{monitoring_dir}/README.md", monitoring_docs)
  end

  desc "deploy monitoring stack"
  task :deploy do
    puts "deploying monitoring stack..."

    monitoring_dir = "config/monitoring"
    unless Dir.exist?(monitoring_dir)
      abort "monitoring configuration not found\nrun 'bundle exec rake monitoring:setup' first"
    end

    # Check if docker-compose is installed
    unless system("which docker-compose > /dev/null 2>&1")
      abort "docker-compose not found\nplease install docker-compose"
    end

    # Ask for deployment details
    print "enter server hostname or ip: "
    server = STDIN.gets.chomp

    print "enter ssh user: "
    user = STDIN.gets.chomp

    # Create remote directory for monitoring
    puts "creating remote directory..."
    system("ssh #{user}@#{server} 'mkdir -p ~/monitoring'")

    # Copy configuration files
    puts "copying configuration files..."
    system("scp #{monitoring_dir}/prometheus.yml #{user}@#{server}:~/monitoring/")
    system("scp #{monitoring_dir}/docker-compose.yml #{user}@#{server}:~/monitoring/")
    system("scp -r #{monitoring_dir}/dashboards #{user}@#{server}:~/monitoring/")

    # Start monitoring stack
    puts "starting monitoring stack..."
    system("ssh #{user}@#{server} 'cd ~/monitoring && docker-compose up -d'")

    puts "\nmonitoring stack deployed!"
    puts "access grafana at http://#{server}:3000"
    puts "- username: admin"
    puts "- password: admin (please change this)"
  end

  desc "set up and configure logstash for centralized logging"
  task :logs do
    puts "setting up centralized logging..."

    # Create logging directory
    logging_dir = "config/logging"
    FileUtils.mkdir_p(logging_dir)

    # Create logstash configuration
    logstash_conf = <<~CONF
      input {
        tcp {
          port => 5000
          codec => json
        }
        http {
          port => 8080
          codec => json
        }
      }

      filter {
        if [service] == "tarot_api" {
          grok {
            match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:log_level} \\[%{DATA:request_id}\\] %{GREEDYDATA:log_message}" }
          }
      #{'    '}
          date {
            match => [ "timestamp", "ISO8601" ]
            target => "@timestamp"
          }
      #{'    '}
          if [log_level] == "ERROR" or [log_level] == "FATAL" {
            mutate {
              add_tag => [ "error" ]
            }
          }
        }
      }

      output {
        elasticsearch {
          hosts => ["elasticsearch:9200"]
          index => "tarot-api-%{+YYYY.MM.dd}"
        }
      #{'  '}
        if "error" in [tags] {
          slack {
            url => "https://hooks.slack.com/services/your/slack/webhook"
            format => "%{service}: %{log_level} - %{log_message}"
          }
        }
      }
    CONF

    # Create docker-compose for ELK stack
    elk_compose = <<~YAML
      version: '3.8'

      services:
        elasticsearch:
          image: docker.elastic.co/elasticsearch/elasticsearch:8.9.1
          container_name: elasticsearch
          environment:
            - discovery.type=single-node
            - ES_JAVA_OPTS=-Xms512m -Xmx512m
            - xpack.security.enabled=false
          volumes:
            - elasticsearch_data:/usr/share/elasticsearch/data
          ports:
            - "9200:9200"
          networks:
            - logging

        logstash:
          image: docker.elastic.co/logstash/logstash:8.9.1
          container_name: logstash
          volumes:
            - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
          ports:
            - "5000:5000"
            - "8080:8080"
          depends_on:
            - elasticsearch
          networks:
            - logging

        kibana:
          image: docker.elastic.co/kibana/kibana:8.9.1
          container_name: kibana
          environment:
            - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
          ports:
            - "5601:5601"
          depends_on:
            - elasticsearch
          networks:
            - logging

      volumes:
        elasticsearch_data:

      networks:
        logging:
        default:
          external:
            name: tarot_api_default
    YAML

    # Create rails logger configuration
    rails_logger = <<~RUBY
      # config/initializers/logstash.rb
      if Rails.env.production? || Rails.env.staging?
        logstash_host = ENV['LOGSTASH_HOST'] || 'logstash'
        logstash_port = ENV['LOGSTASH_PORT'] || 5000
      #{'  '}
        logger = LogStashLogger.new(
          type: :tcp,
          host: logstash_host,
          port: logstash_port,
          buffer_max_items: 50,
          buffer_max_interval: 5,
          customize_event: lambda do |event|
            event['service'] = 'tarot_api'
            event['environment'] = Rails.env
            event
          end
        )
      #{'  '}
        Rails.application.configure do
          config.logstash.logger = logger
          config.log_level = ENV.fetch('LOG_LEVEL', 'info').to_sym
        end
      end
    RUBY

    # Write configuration files
    File.write("#{logging_dir}/logstash.conf", logstash_conf)
    File.write("#{logging_dir}/docker-compose.yml", elk_compose)
    File.write("#{logging_dir}/logstash_initializer.rb", rails_logger)

    # Create documentation
    logging_docs = <<~MD
      # Centralized Logging for Tarot API

      This directory contains the ELK (Elasticsearch, Logstash, Kibana) stack configuration for centralized logging.

      ## Components

      - **Elasticsearch**: Search and analytics engine
      - **Logstash**: Log processing pipeline
      - **Kibana**: Visualization and analysis UI

      ## Setup

      1. Deploy the Tarot API using Kamal
      2. Deploy the ELK stack:

         ```bash
         bundle exec rake monitoring:logs:deploy
         ```

      3. Add the LogStash initializer to your Rails application:

         ```bash
         cp config/logging/logstash_initializer.rb config/initializers/logstash.rb
         ```

      4. Add the gem to your Gemfile:

         ```ruby
         gem 'logstash-logger'
         ```

      5. Update your Kamal deploy.yml to include the logging environment variables:

         ```yaml
         env:
           clear:
             LOGSTASH_HOST: logstash
             LOGSTASH_PORT: 5000
             LOG_LEVEL: info
         ```

      6. Access Kibana at http://your-server:5601

      ## Log Format

      The logstash configuration parses Rails logs in the following format:

      ```
      2023-08-15T10:15:30Z INFO [abcd1234] User login successful
      ```

      ## Searching Logs

      In Kibana, you can search logs with queries like:

      - `log_level:ERROR`: Find all error logs
      - `service:tarot_api AND log_message:*login*`: Find login-related logs
      - `request_id:abcd1234`: Find all logs for a specific request

      ## Log Retention

      Logs are stored in daily indices with a 30-day retention period by default.

      ## References

      - [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
      - [Logstash Documentation](https://www.elastic.co/guide/en/logstash/current/index.html)
      - [Kibana Documentation](https://www.elastic.co/guide/en/kibana/current/index.html)
      - [LogStash Logger for Rails](https://github.com/dwbutler/logstash-logger)
    MD

    File.write("#{logging_dir}/README.md", logging_docs)

    puts "logging configuration created in #{logging_dir}"
    puts "\nnext steps:"
    puts "1. review configuration files in #{logging_dir}"
    puts "2. add the gem to your Gemfile: gem 'logstash-logger'"
    puts "3. copy the initializer: cp #{logging_dir}/logstash_initializer.rb config/initializers/logstash.rb"
    puts "4. deploy logging with 'bundle exec rake monitoring:logs:deploy'"
  end

  namespace :logs do
    desc "deploy logging stack"
    task :deploy do
      puts "deploying logging stack..."

      logging_dir = "config/logging"
      unless Dir.exist?(logging_dir)
        abort "logging configuration not found\nrun 'bundle exec rake monitoring:logs' first"
      end

      # Check if docker-compose is installed
      unless system("which docker-compose > /dev/null 2>&1")
        abort "docker-compose not found\nplease install docker-compose"
      end

      # Ask for deployment details
      print "enter server hostname or ip: "
      server = STDIN.gets.chomp

      print "enter ssh user: "
      user = STDIN.gets.chomp

      # Create remote directory for logging
      puts "creating remote directory..."
      system("ssh #{user}@#{server} 'mkdir -p ~/logging'")

      # Copy configuration files
      puts "copying configuration files..."
      system("scp #{logging_dir}/logstash.conf #{user}@#{server}:~/logging/")
      system("scp #{logging_dir}/docker-compose.yml #{user}@#{server}:~/logging/")

      # Start logging stack
      puts "starting logging stack..."
      system("ssh #{user}@#{server} 'cd ~/logging && docker-compose up -d'")

      puts "\nlogging stack deployed!"
      puts "access kibana at http://#{server}:5601"

      # Update kamal config to include logging
      puts "\nto connect your application to the logging stack, update your deploy.yml:"
      puts "env:"
      puts "  clear:"
      puts "    LOGSTASH_HOST: #{server}"
      puts "    LOGSTASH_PORT: 5000"
      puts "    LOG_LEVEL: info"
    end
  end

  desc "create ssl certificate"
  task :ssl do
    puts "setting up ssl certificates..."

    # Check if certbot is installed
    unless system("which certbot > /dev/null 2>&1")
      puts "certbot not found, please install it:"
      puts "ubuntu: apt install certbot"
      puts "macos: brew install certbot"
      abort "certbot required for ssl certificate generation"
    end

    # Get domain information
    print "enter your domain (e.g., tarotapi.cards): "
    domain = STDIN.gets.chomp

    print "include www subdomain? [y/N]: "
    www = STDIN.gets.chomp.downcase == "y"

    domains = www ? "-d #{domain} -d www.#{domain}" : "-d #{domain}"

    print "enter your email address for certificate notifications: "
    email = STDIN.gets.chomp

    # Generate certificate
    puts "generating ssl certificate..."

    print "use staging server for testing? [y/N]: "
    staging = STDIN.gets.chomp.downcase == "y"

    staging_flag = staging ? "--staging" : ""

    command = "certbot certonly --standalone #{staging_flag} #{domains} --email #{email} --agree-tos -n"

    if system(command)
      puts "\nssl certificate generated successfully!"
      puts "certificate path: /etc/letsencrypt/live/#{domain}/fullchain.pem"
      puts "private key path: /etc/letsencrypt/live/#{domain}/privkey.pem"

      # Update kamal config instructions
      puts "\nto use this certificate with kamal, update your deploy.yml:"
      puts "traefik:"
      puts "  options:"
      puts "    volume:"
      puts "      - \"/etc/letsencrypt:/etc/letsencrypt\""
      puts "  args:"
      puts "    entryPoints.websecure.http.tls.certresolver: myresolver"
      puts "    certificatesResolvers.myresolver.acme.email: \"#{email}\""
      puts "    certificatesResolvers.myresolver.acme.storage: \"/etc/letsencrypt/acme.json\""
      puts "    certificatesResolvers.myresolver.acme.httpChallenge.entryPoint: \"web\""
    else
      abort "certificate generation failed"
    end
  end

  desc "show monitoring status"
  task :status do
    puts "checking monitoring status..."

    # List of monitoring services to check
    services = [ "prometheus", "grafana", "kibana", "elasticsearch", "logstash" ]

    # Ask for server info
    print "enter server hostname or ip: "
    server = STDIN.gets.chomp

    print "enter ssh user: "
    user = STDIN.gets.chomp

    # Check each service
    services.each do |service|
      puts "\nchecking #{service}..."
      system("ssh #{user}@#{server} 'docker ps --filter \"name=#{service}\" --format \"{{.Status}}\"'")
    end

    # Check disk space
    puts "\nchecking disk space..."
    system("ssh #{user}@#{server} 'df -h'")

    # Check memory usage
    puts "\nchecking memory usage..."
    system("ssh #{user}@#{server} 'free -h'")

    puts "\nmonitoring status check complete"
  end

  desc "show monitoring help"
  task :help do
    puts <<~HELP
      monitoring and logging commands:

      setup:
        bundle exec rake monitoring:setup        # set up prometheus and grafana monitoring
        bundle exec rake monitoring:logs         # set up ELK stack for centralized logging
        bundle exec rake monitoring:ssl          # set up ssl certificates

      deployment:
        bundle exec rake monitoring:deploy       # deploy monitoring stack
        bundle exec rake monitoring:logs:deploy  # deploy logging stack

      management:
        bundle exec rake monitoring:status       # check monitoring status

      integration with kamal:
        - update deploy.yml to include monitoring and logging configuration
        - add logstash-logger gem to your Gemfile
        - add logstash initializer to config/initializers/
    HELP
  end
end

# alias for convenience
desc "set up monitoring (alias for monitoring:setup)"
task monitor: "monitoring:setup"
