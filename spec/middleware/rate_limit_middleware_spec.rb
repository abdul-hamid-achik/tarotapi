require 'rails_helper'

RSpec.describe RateLimitMiddleware do
  let(:app) { ->(env) { [ 200, env, [ 'OK' ] ] } }
  let(:middleware) { RateLimitMiddleware.new(app) }

  let(:request_env) do
    Rack::MockRequest.env_for("http://example.org/api/v1/readings",
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_ACCEPT" => "application/json"
    )
  end

  let(:redis) { instance_double(Redis) }

  before do
    allow(Redis).to receive(:new).and_return(redis)
    allow(redis).to receive(:get).and_return("0")
    allow(redis).to receive(:setex)
    allow(redis).to receive(:incr)
    allow(redis).to receive(:ttl).and_return(3600)
  end

  describe "#call" do
    context "when in test environment with SKIP_RATE_LIMIT" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))
        allow(ENV).to receive(:[]).with("SKIP_RATE_LIMIT").and_return("true")
      end

      it "skips rate limiting" do
        expect(app).to receive(:call).with(request_env).and_return([ 200, {}, [ "OK" ] ])
        middleware.call(request_env)
      end
    end

    context "when request should be rate limited" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        allow(middleware).to receive(:should_rate_limit?).and_return(true)
        allow(middleware).to receive(:extract_client_identifier).and_return("127.0.0.1")
        allow(middleware).to receive(:normalized_path).and_return("api_general")
      end

      context "when rate limit is not exceeded" do
        before do
          allow(redis).to receive(:get).with("rate_limit:api_general:127.0.0.1").and_return("5")
          allow(redis).to receive(:incr).with("rate_limit:api_general:127.0.0.1").and_return(6)
          allow(redis).to receive(:ttl).with("rate_limit:api_general:127.0.0.1").and_return(3000)
        end

        it "adds rate limit headers to response" do
          status, headers, response = middleware.call(request_env)

          expect(status).to eq(200)
          expect(headers["X-RateLimit-Limit"]).to eq("300")
          expect(headers["X-RateLimit-Remaining"]).to eq("294")
          expect(headers["X-RateLimit-Reset"]).to be_a(String)
        end
      end

      context "when rate limit is exceeded" do
        before do
          allow(redis).to receive(:get).with("rate_limit:api_general:127.0.0.1").and_return("300")
          allow(redis).to receive(:incr).with("rate_limit:api_general:127.0.0.1").and_return(301)
          allow(redis).to receive(:ttl).with("rate_limit:api_general:127.0.0.1").and_return(1000)
        end

        it "returns a 429 rate limit exceeded response" do
          status, headers, response = middleware.call(request_env)

          expect(status).to eq(429)
          expect(headers["X-RateLimit-Limit"]).to eq("300")
          expect(headers["X-RateLimit-Remaining"]).to eq("0")

          body = JSON.parse(response.first)
          expect(body["error"]).to eq("rate limit exceeded")
          expect(body).to have_key("retry_after")
        end
      end
    end

    context "when request should not be rate limited" do
      before do
        allow(middleware).to receive(:should_rate_limit?).and_return(false)
        allow(app).to receive(:call).with(request_env).and_return([ 200, {}, [ "OK" ] ])
      end

      it "passes the request through without rate limiting" do
        status, headers, response = middleware.call(request_env)

        expect(status).to eq(200)
        expect(headers).not_to have_key("X-RateLimit-Limit")
      end
    end
  end

  describe "#should_rate_limit?" do
    it "returns true for API endpoints" do
      api_requests = [
        Rack::MockRequest.env_for("http://example.org/api/v1/readings"),
        Rack::MockRequest.env_for("http://example.org/api/v1/seance"),
        Rack::MockRequest.env_for("http://example.org/api/v1/reading_sessions/123")
      ]

      api_requests.each do |req_env|
        request = Rack::Request.new(req_env)
        expect(middleware.send(:should_rate_limit?, request)).to be true
      end
    end

    it "returns false for non-API endpoints" do
      non_api_requests = [
        Rack::MockRequest.env_for("http://example.org/"),
        Rack::MockRequest.env_for("http://example.org/about"),
        Rack::MockRequest.env_for("http://example.org/users/sign_in")
      ]

      non_api_requests.each do |req_env|
        request = Rack::Request.new(req_env)
        expect(middleware.send(:should_rate_limit?, request)).to be false
      end
    end
  end

  describe "#normalized_path" do
    it "returns 'seance' for seance endpoints" do
      request = Rack::Request.new(Rack::MockRequest.env_for("http://example.org/api/v1/seance"))
      expect(middleware.send(:normalized_path, request)).to eq("seance")
    end

    it "returns 'reading_sessions' for reading_sessions endpoints" do
      request = Rack::Request.new(Rack::MockRequest.env_for("http://example.org/api/v1/reading_sessions"))
      expect(middleware.send(:normalized_path, request)).to eq("reading_sessions")
    end

    it "returns 'api_general' for other API endpoints" do
      request = Rack::Request.new(Rack::MockRequest.env_for("http://example.org/api/v1/readings"))
      expect(middleware.send(:normalized_path, request)).to eq("api_general")
    end
  end

  describe "#get_rate_limit_info" do
    context "for different endpoint types" do
      it "sets appropriate limits for seance endpoints" do
        request = Rack::Request.new(Rack::MockRequest.env_for("http://example.org/api/v1/seance"))
        allow(middleware).to receive(:normalized_path).and_return("seance")

        allow(redis).to receive(:get).with("rate_limit:seance:127.0.0.1").and_return(nil)
        allow(redis).to receive(:setex).with("rate_limit:seance:127.0.0.1", 3600, 1)
        allow(redis).to receive(:ttl).with("rate_limit:seance:127.0.0.1").and_return(3600)

        limit, remaining, reset_time = middleware.send(:get_rate_limit_info, "rate_limit:seance:127.0.0.1", request)

        expect(limit).to eq(30)
        expect(remaining).to eq(29)
        expect(reset_time).to be > Time.now
      end

      it "sets appropriate limits for reading_sessions endpoints" do
        request = Rack::Request.new(Rack::MockRequest.env_for("http://example.org/api/v1/reading_sessions"))
        allow(middleware).to receive(:normalized_path).and_return("reading_sessions")

        allow(redis).to receive(:get).with("rate_limit:reading_sessions:127.0.0.1").and_return(nil)
        allow(redis).to receive(:setex).with("rate_limit:reading_sessions:127.0.0.1", 3600, 1)
        allow(redis).to receive(:ttl).with("rate_limit:reading_sessions:127.0.0.1").and_return(3600)

        limit, remaining, reset_time = middleware.send(:get_rate_limit_info, "rate_limit:reading_sessions:127.0.0.1", request)

        expect(limit).to eq(60)
        expect(remaining).to eq(59)
        expect(reset_time).to be > Time.now
      end

      it "sets appropriate limits for general API endpoints" do
        request = Rack::Request.new(Rack::MockRequest.env_for("http://example.org/api/v1/readings"))
        allow(middleware).to receive(:normalized_path).and_return("api_general")

        allow(redis).to receive(:get).with("rate_limit:api_general:127.0.0.1").and_return(nil)
        allow(redis).to receive(:setex).with("rate_limit:api_general:127.0.0.1", 3600, 1)
        allow(redis).to receive(:ttl).with("rate_limit:api_general:127.0.0.1").and_return(3600)

        limit, remaining, reset_time = middleware.send(:get_rate_limit_info, "rate_limit:api_general:127.0.0.1", request)

        expect(limit).to eq(300)
        expect(remaining).to eq(299)
        expect(reset_time).to be > Time.now
      end
    end

    context "when counter already exists" do
      it "increments the counter and calculates remaining correctly" do
        request = Rack::Request.new(Rack::MockRequest.env_for("http://example.org/api/v1/readings"))
        allow(middleware).to receive(:normalized_path).and_return("api_general")

        allow(redis).to receive(:get).with("rate_limit:api_general:127.0.0.1").and_return("10")
        allow(redis).to receive(:incr).with("rate_limit:api_general:127.0.0.1").and_return(11)
        allow(redis).to receive(:ttl).with("rate_limit:api_general:127.0.0.1").and_return(1800)

        limit, remaining, reset_time = middleware.send(:get_rate_limit_info, "rate_limit:api_general:127.0.0.1", request)

        expect(limit).to eq(300)
        expect(remaining).to eq(289)
        expect(reset_time).to be > Time.now
      end
    end
  end
end
