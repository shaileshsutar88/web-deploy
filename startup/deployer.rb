#!/usr/bin/env ruby

require "aws-sdk-v1"
require "deep_merge"
require "etc"
require "fileutils"
require "json"
require "net/http"
require "net/https"
require "open-uri"
require "yaml"

module DeepMerger
  def deep_merge(other_hash, &block)
    dup.deep_merge!(other_hash, &block)
  end
  def deep_merge!(other_hash, &block)
    other_hash.each_pair do |k,v|
      tv = self[k]
      if tv.is_a?(Hash) && v.is_a?(Hash)
        self[k] = tv.deep_merge(v, &block)
      else
        self[k] = block && tv ? block.call(k, tv, v) : v
      end
    end
    self
  end
end
unless {}.respond_to?(:deep_merge)
  Hash.send :include, DeepMerger
end

CHEF_ROOT_PATH = File.expand_path("../../", __FILE__)

module Notifier
  class Slack
    def info(msg)
      notify msg, icon_emoji: ':shipit:'
    end

    def success(msg)
      notify msg, icon_emoji: ':beers:'
    end

    def error(msg)
      notify msg, icon_emoji: ':boom:'
    end

    private

    def notify(msg, opts = {})
      # TODO notify configuration
    end

    def defaults
      {
        username: "testuser"
      }
    end
  end
end

module Notifier
  class StdOut
    def info(msg)
      puts "=> \033[34m#{msg}\033[0m"
    end

    def success(msg)
      puts "=> \033[32m#{msg}\033[0m"
    end

    def error(msg)
      puts "=> \033[31m#{msg}\033[0m"
    end
  end
end

module Runner
  class Command
    def execute(cmd)
      system cmd
    end
  end
end

module Runner
  class Debug
    def execute(cmd)
      puts "Executing: #{cmd}"
      true
    end
  end
end

class RunConfiguration
  attr_accessor :instance, :configuration

  def initialize(instance)
    @instance = instance
    @configuration = load_configuration
  end

  def to_json(path = nil)
    write_to_file(path) if path
    json
  end

  private

  def write_to_file(path)
    File.open(path, "w") do |f|
      f.write(json)
    end
  end

  def json
    @json ||= JSON.pretty_generate(configuration)
  end

  # TODO if node == base, don't merge node specific config
  def load_configuration
    shared_configuration.deep_merge(node_configuration).deep_merge(overrides_configuration)
  end

  def shared_configuration
    @shared_configuration ||= YAML::load(File.open(shared_configuration_path).read)
  end

  # TODO if node config doesn't exist (due to invalid node tag) exit immediately
  def node_configuration
    @node_configuration ||= YAML::load(File.open(node_configuration_path).read)
  end

  def node_configuration_path
    File.join(environment_path, "#{instance.node}.yml")
  end

  def shared_configuration_path
    File.join(environment_path, "_shared.yml")
  end

  def overrides_configuration
    if File.exist? overrides_path
      config = YAML.load(File.open(overrides_path).read)
      puts ""
      puts "\e[31m *** USING LOCAL OVERRIDES FOR PROJECTS: #{config.keys.map(&:to_s).join(", ")} *** \e[0m"
      puts ""
      sleep 2
      config
    else
      {}
    end
  end

  def overrides_path
    File.join(CHEF_ROOT_PATH, "overrides.yml")
  end

  def environment_path
    File.join(root_path, instance.environment)
  end

  def root_path
    File.join(CHEF_ROOT_PATH, "nodes")
  end
end

module Instance
  class Basic
    attr_accessor :environment, :node, :name

    def initialize
      write_meta_data_to_environment_vars
    end

    def notifier
      @notifier ||= Notifier::StdOut.new
    end

    def runner
      @runner ||= Runner::Debug.new
    end

    private

    def write_meta_data_to_environment_vars
      meta_data = <<EOF
export VM_ENV="#{environment}"
export VM_NODE="#{node}"
export VM_NAME="#{name}"
EOF
      File.open("/etc/profile.d/instance_meta_data.sh", "w") do |f|
        f.write(meta_data)
      end
    end

    def require_root_privileges
      # Exit immediately if not using sudo
      if Process.uid != 0
        puts "Please use: sudo #{$0} #{ARGV.join(" ")}"
        exit 1
      end
    end
  end
end

module Instance
  class EC2 < Basic
    def initialize
      require_root_privileges
      fetch_meta_data
      fetch_node_data
      super
    end

    def description
      "#{@name} on host #{@hostname} (#{@ip})"
    end

    def notifier
      @notifier ||= Notifier::Slack.new
    end

    def runner
      Runner::Command.new
    end

    private

    def fetch_meta_data
      instance_id  = open("http://169.254.169.254/latest/meta-data/instance-id") {|f| f.read }

      tags         = AWS::EC2.new.instances[instance_id].tags.to_h
      @name        = ENV["EC2_NAME"] || tags["Name"]
      @environment = ENV["EC2_ENV"]  || tags["environment"]
      @node        = ENV["EC2_NODE"] || tags["node"]
    end

    def fetch_node_data
      @hostname = Socket.gethostname
      @ip       = Socket.ip_address_list.map(&:ip_address).reject{|i| i !~ /^10\./}.first
    end
  end
end

module Instance
  class Fake < Basic
    def initialize
      @name        = "fake"
      @node        = "nat"
      @environment = "staging"
      super
    end

    def description
      "fake instance"
    end
  end
end

class Deployment
  attr_accessor :timestamp, :instance, :notifier

  def initialize(instance)
    @timestamp = Time.now.utc.strftime("%Y%m%dT%H%M%S")
    @instance  = instance

    instance.notifier.info "#{user} is deploying to #{instance.description} using #{attributes_path}"

    if pull && compile_configuration && run_chef_solo
      cleanup
      instance.notifier.success "Done deploying to #{instance.description}"
    else
      instance.notifier.error "Failed deploying to #{instance.description}"
    end
  end

  private

  def user
    @user ||= ENV['DEPLOYING_USER'] || Etc.getlogin
  end

  def attributes_path
    @attributes_path ||= File.join(CHEF_ROOT_PATH, "tmp", "#{instance.environment}-#{instance.node}-#{timestamp}.json")
  end

  def configuration_path
    @configuration_path ||= File.join(CHEF_ROOT_PATH, "config", "solo.rb")
  end

  def compile_configuration
    configuration = RunConfiguration.new(instance)
    configuration.to_json(attributes_path)
    true
  end

  def cleanup
    # TODO remove configuration
  end

  def pull
    cmd = "cd #{CHEF_ROOT_PATH}; sudo git pull --no-rebase"
    instance.runner.execute(cmd)
  end

  # DEPLOY ALL THE THINGS. chef-solo runs without a HOME env var, to
  # prevent git from choking on user permissions. More details:
  # http://tickets.opscode.com/browse/CHEF-3940
  def run_chef_solo
    cmd = "cd #{CHEF_ROOT_PATH}; HOME='' sudo chef-solo -c #{configuration_path} -j #{attributes_path}"
    instance.runner.execute(cmd)
  end
end

instance = case ARGV[0]
  when "fake"    then Instance::Fake.new
  else                Instance::EC2.new
end

Deployment.new(instance)