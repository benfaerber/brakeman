require 'set'

module Brakeman
  class InlineIgnore
    PATTERN = /\#\s*brakeman:disable\s+(.+)/

    def initialize
      @file_cache = {}
    end

    def ignored?(warning)
      file = warning.file
      line = warning.line

      return false unless file && line && warning.check

      check_name = warning.check_name
      disabled_checks = disabled_checks_at(file, line)
      return false if disabled_checks.empty?

      disabled_checks.include?("all") || disabled_checks.include?(check_name)
    end

    private

    def disabled_checks_at(file, line)
      directives = directives_for(file)
      return Set.new if directives.empty?

      result = Set.new
      result.merge(directives[line]) if directives[line]
      result.merge(directives[line - 1]) if directives[line - 1]
      result
    end

    def directives_for(file)
      path = file.absolute
      return @file_cache[path] if @file_cache.key?(path)

      @file_cache[path] = parse_directives(file)
    end

    def parse_directives(file)
      directives = {}

      return directives unless file.exists?

      file.read.each_line.with_index(1) do |source_line, line_number|
        match = source_line.match(PATTERN)
        next unless match

        check_names = match[1].split(",").map(&:strip).reject(&:empty?)
        directives[line_number] = Set.new(check_names)
      end

      directives
    end
  end
end
