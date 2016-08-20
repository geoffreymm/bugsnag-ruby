require "set"
require "socket"
require "logger"
require "bugsnag/middleware_stack"

module Bugsnag
  class Configuration
    attr_accessor :api_key
    attr_accessor :release_stage
    attr_accessor :notify_release_stages
    attr_accessor :auto_notify
    attr_accessor :ca_file
    attr_accessor :send_environment
    attr_accessor :send_code
    attr_accessor :project_root
    attr_accessor :app_version
    attr_accessor :app_type
    attr_accessor :meta_data_filters
    attr_accessor :endpoint
    attr_accessor :logger
    attr_accessor :middleware
    attr_accessor :internal_middleware
    attr_accessor :proxy_host
    attr_accessor :proxy_port
    attr_accessor :proxy_user
    attr_accessor :proxy_password
    attr_accessor :timeout
    attr_accessor :hostname
    attr_accessor :delivery_method
    attr_accessor :ignore_classes

    LOG_PREFIX = "** [Bugsnag] "

    THREAD_LOCAL_NAME = "bugsnag_req_data"

    DEFAULT_PARAMS_FILTERS = [
      /authorization/i,
      /cookie/i,
      /password/i,
      /secret/i,
      "rack.request.form_vars"
    ].freeze

    def initialize
      @mutex = Mutex.new

      # Set up the defaults
      self.auto_notify = true
      self.send_environment = false
      self.send_code = true
      self.params_filters = Set.new(DEFAULT_PARAMS_FILTERS)
      self.ignore_classes = Set.new([])
      self.endpoint = "https://notify.bugsnag.com"
      self.hostname = default_hostname
      self.delivery_method = :thread_queue
      self.timeout = 15
      self.notify_release_stages = nil

      # Read the API key from the environment
      self.api_key = ENV["BUGSNAG_API_KEY"]

      # Set up logging
      self.logger = Logger.new(STDOUT)
      self.logger.level = Logger::INFO

      # Configure the bugsnag middleware stack
      self.internal_middleware = Bugsnag::MiddlewareStack.new

      self.middleware = Bugsnag::MiddlewareStack.new
      self.middleware.use Bugsnag::Middleware::Callbacks
    end

    def should_notify_release_stage?
      if @release_stage.nil? || @notify_release_stages.nil? || @notify_release_stages.include?(@release_stage)
        return true
      else
        warn "Not notifying in release stage #{@release_stage}"
        return false
      end
    end

    def valid_api_key?
      if api_key.nil?
        warn "No API key configured, couldn't notify"
        return false
      elsif api_key !~ API_KEY_REGEX
        warn "Your API key (#{api_key}) is not valid, couldn't notify"
        return false
      end

      return true
    end

    def request_data
      Thread.current[THREAD_LOCAL_NAME] ||= {}
    end

    def set_request_data(key, value)
      self.request_data[key] = value
    end

    def unset_request_data(key, value)
      self.request_data.delete(key)
    end

    def clear_request_data
      Thread.current[THREAD_LOCAL_NAME] = nil
    end

    def info(message)
      configuration.logger.info("#{LOG_PREFIX}#{message}")
    end

    # Warning logger
    def warn(message)
      configuration.logger.warn("#{LOG_PREFIX}#{message}")
    end

    # Debug logger
    def debug(message)
      configuration.logger.debug("#{LOG_PREFIX}#{message}")
    end

    private

    def default_hostname
      # Don't send the hostname on Heroku
      Socket.gethostname unless ENV["DYNO"]
    end
  end
end
