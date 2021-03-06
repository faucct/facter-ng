# frozen_string_literal: true

module Facter
  class CacheManager
    def initialize
      @groups = {}
      @log = Log.new(self)
      @fact_groups = Facter::FactGroups.new
      @cache_dir = LegacyFacter::Util::Config.facts_cache_dir
    end

    def resolve_facts(searched_facts)
      return searched_facts, [] if !File.directory?(@cache_dir) || !Options[:cache]

      facts = []
      searched_facts.each do |fact|
        res = resolve_fact(fact)
        facts << res if res
      end
      facts.each do |fact|
        searched_facts.delete_if { |f| f.name == fact.name }
      end
      [searched_facts, facts]
    end

    def cache_facts(resolved_facts)
      return unless Options[:cache]

      resolved_facts.each do |fact|
        cache_fact(fact)
      end

      begin
        write_cache unless @groups.empty?
      rescue Errno::EACCES => e
        @log.warn("Could not write cache: #{e.message}")
      end
    end

    private

    def resolve_fact(searched_fact)
      group_name = @fact_groups.get_fact_group(searched_fact.name)
      return unless group_name

      return unless group_cached?(group_name)

      return unless check_ttls?(group_name)

      data = read_group_json(group_name)
      return unless data

      @log.debug("loading cached values for #{group_name} facts")
      create_fact(searched_fact, data[searched_fact.name])
    end

    def create_fact(searched_fact, value)
      Facter::ResolvedFact.new(searched_fact.name, value, searched_fact.type,
                               searched_fact.user_query, searched_fact.filter_tokens)
    end

    def cache_fact(fact)
      group_name = @fact_groups.get_fact_group(fact.name)
      return if !group_name || fact.value.nil?

      return unless group_cached?(group_name)

      @groups[group_name] ||= {}
      @groups[group_name][fact.name] = fact.value
    end

    def write_cache
      unless File.directory?(@cache_dir)
        require 'fileutils'
        FileUtils.mkdir_p(@cache_dir)
      end

      @groups.each do |group_name, data|
        next unless check_ttls?(group_name)

        @log.debug("caching values for #{group_name} facts")
        cache_file_name = File.join(@cache_dir, group_name)
        File.write(cache_file_name, JSON.pretty_generate(data))
      end
    end

    def read_group_json(group_name)
      return @groups[group_name] if @groups.key?(group_name)

      cache_file_name = File.join(@cache_dir, group_name)
      data = nil
      file = Util::FileHelper.safe_read(cache_file_name)
      begin
        data = JSON.parse(file)
      rescue JSON::ParserError
        delete_cache(group_name)
      end
      @groups[group_name] = data
    end

    def group_cached?(group_name)
      cached = @fact_groups.get_group_ttls(group_name) ? true : false
      delete_cache(group_name) unless cached
      cached
    end

    def check_ttls?(group_name)
      ttls = @fact_groups.get_group_ttls(group_name)
      return false unless ttls

      cache_file_name = File.join(@cache_dir, group_name)
      if File.readable?(cache_file_name)
        file_time = File.mtime(cache_file_name)
        expire_date = file_time + ttls
        return true if expire_date > Time.now

        File.delete(cache_file_name)
      end

      @log.debug("#{group_name} facts cache file expired/missing")
      true
    end

    def delete_cache(group_name)
      cache_file_name = File.join(@cache_dir, group_name)
      File.delete(cache_file_name) if File.readable?(cache_file_name)
    end
  end
end
