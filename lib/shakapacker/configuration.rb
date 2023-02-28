require "yaml"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/hash/indifferent_access"

class Shakapacker::Configuration
  class << self
    attr_accessor :installing
  end

  attr_reader :root_path, :config_path, :env

  def initialize(root_path:, config_path:, env:)
    @root_path = root_path
    @config_path = config_path
    @env = env

    Shakapacker.set_shakapacker_env_variables_for_backward_compatibility
  end

  def dev_server
    fetch(:dev_server)
  end

  def compile?
    fetch(:compile)
  end

  def nested_entries?
    fetch(:nested_entries)
  end

  def ensure_consistent_versioning?
    fetch(:ensure_consistent_versioning)
  end

  def shakapacker_precompile?
    # ENV of false takes precedence
    return false if %w(no false n f).include?(ENV["SHAKAPACKER_PRECOMPILE"])
    return true if %w(yes true y t).include?(ENV["SHAKAPACKER_PRECOMPILE"])

    return false unless config_path.exist?
    fetch(:shakapacker_precompile)
  end

  def webpacker_precompile?
    Shakapacker.puts_deprecation_message(
      Shakapacker.short_deprecation_message(
        "webpacker_precompile?",
        "shakapacker_precompile?"
      )
    )

    shakapacker_precompile?
  end

  def source_path
    root_path.join(fetch(:source_path))
  end

  def additional_paths
    fetch(:additional_paths)
  end

  def source_entry_path
    source_path.join(fetch(:source_entry_path))
  end

  def manifest_path
    if data.has_key?(:manifest_path)
      root_path.join(fetch(:manifest_path))
    else
      public_output_path.join("manifest.json")
    end
  end

  def public_manifest_path
    manifest_path
  end

  def public_path
    root_path.join(fetch(:public_root_path))
  end

  def public_output_path
    public_path.join(fetch(:public_output_path))
  end

  def cache_manifest?
    fetch(:cache_manifest)
  end

  def cache_path
    root_path.join(fetch(:cache_path))
  end

  def check_yarn_integrity=(value)
    warn <<~EOS
      Shakapacker::Configuration#check_yarn_integrity=(value) is obsolete. The integrity
      check has been removed from Webpacker (https://github.com/rails/webpacker/pull/2518)
      so changing this setting will have no effect.
    EOS
  end

  def webpack_compile_output?
    fetch(:webpack_compile_output)
  end

  def compiler_strategy
    fetch(:compiler_strategy)
  end

  def fetch(key)
    # for backward compatibility
    return data.fetch(key, defaults[key]) unless key == :shakapacker_precompile

    return data.fetch(:shakapacker_precompile) if data.key?(:shakapacker_precompile)

    Shakapacker.puts_deprecation_message(
      Shakapacker.short_deprecation_message(
        "webpacker_precompile",
        "shakapacker_precompile"
      )
    )

    data.fetch(:webpacker_precompile, defaults[key])
  end

  private
    def data
      @data ||= load
    end

    def load
      config = begin
        YAML.load_file(config_path.to_s, aliases: true)
      rescue ArgumentError
        YAML.load_file(config_path.to_s)
      end
      config[env].deep_symbolize_keys
    rescue Errno::ENOENT => e
      if self.class.installing
        {}
      else
        raise "Shakapacker configuration file not found #{config_path}. " \
              "Please run rails shakapacker:install " \
              "Error: #{e.message}"
      end
    rescue Psych::SyntaxError => e
      raise "YAML syntax error occurred while parsing #{config_path}. " \
            "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
            "Error: #{e.message}"
    end

    def defaults
      @defaults ||= begin
        path = File.expand_path("../../install/config/shakapacker.yml", __FILE__)
        config = begin
          YAML.load_file(path, aliases: true)
        rescue ArgumentError
          YAML.load_file(path)
        end
        HashWithIndifferentAccess.new(config[env] || config[Shakapacker::DEFAULT_ENV])
      end
    end
end
