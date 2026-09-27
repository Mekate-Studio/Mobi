# frozen_string_literal: true

require_relative 'core'
require 'yaml'

module Maintenance
  module KotlinEvidence
    VERSIONS = %w[0.11.1 0.12.2].freeze

    def self.clean(text, source: nil)
      value = text.gsub(/\e\[[0-9;]*m/, '')
      if source
        [source, File.realpath(source)].uniq.sort_by { |p| -p.length }.each do |prefix|
          value = value.gsub(prefix, '{source}').gsub(prefix.delete_prefix('/'), '{source}')
        end
      end
      value
    end

    def self.settings(text, modules:, version:, source: nil)
      raise Failure, 'Unsupported Toolchain output version' unless VERSIONS.include?(version)
      text = clean(text)
      sections = text.split(/^Module: ([a-zA-Z0-9_-]+)\s*$/)
      raise Failure, 'Missing effective settings modules' unless sections.size > 1
      result = {}
      sections.drop(1).each_slice(2) do |name, body|
        raise Failure, 'Duplicate effective settings module' if result.key?(name)
        settings_text = body.lines.drop_while { |line| !line.start_with?('settings') }.join
        data = YAML.safe_load(settings_text, permitted_classes: [], permitted_symbols: [], aliases: false)
        unless data.is_a?(Hash) && !data.empty? && data.keys.all? { |key| key.match?(/\Asettings(?:@[A-Za-z0-9+]+)?\z/) }
          raise Failure, 'Unrecognized effective settings output'
        end
        result[name] = source ? JSON.parse(clean(JSON.generate(data), source: source)) : data
      end
      raise Failure, 'Effective settings module coverage differs' unless result.keys.sort == modules.sort
      result
    rescue Psych::Exception
      raise Failure, 'Cannot parse effective settings output'
    end

    def self.graphs(text, modules:, version:)
      raise Failure, 'Unsupported Toolchain graph version' unless VERSIONS.include?(version)
      graphs = []; declared = []; current = nil; stack = []
      clean(text).each_line do |raw|
        line = raw.rstrip
        if (match = line.match(/^Dependencies of module ([A-Za-z0-9_-]+):\s*$/))
          declared << match[1]; current = nil
        elsif (match = line.match(/^Module ([A-Za-z0-9_-]+)$/))
          raise Failure, 'Graph module header disagrees with section' unless declared.last == match[1]
          current = { 'module' => match[1], 'nodes' => [], 'edges' => [] }; graphs << current; stack = []
        elsif line.start_with?('│ -')
          raise Failure, 'Graph metadata without a root' unless current
          case line
          when '│ - main', '│ - test' then current['usage'] = line.delete_prefix('│ - ')
          when /\A│ - scope = (COMPILE|RUNTIME)\z/ then current['scope'] = Regexp.last_match(1).downcase
          when /\A│ - platforms = \[([A-Za-z0-9, ]+)\]\z/ then current['platforms'] = Regexp.last_match(1).split(', ').sort
          else raise Failure, 'Unknown dependency graph metadata'
          end
        elsif (match = line.match(/\A([│ ]*)(?:├───|╰───) (.+)\z/))
          raise Failure, 'Graph edge without a root' unless current
          raise Failure, 'Unknown dependency graph indentation' unless (match[1].length % 5).zero?
          depth = match[1].length / 5
          raise Failure, 'Dependency graph skipped a parent' if depth > stack.length
          label = match[2]
          raise Failure, 'Unresolved dependency graph node' if label.match?(/FAILED|unresolved|not found/i)
          id = current['nodes'].size
          node = { 'id' => id, 'label' => label, 'repeated' => label.end_with?('(*)'), 'constraint' => label.end_with?('(c)') }
          # Labels include request/fragment nodes. Preserve those edges; do not
          # collapse a request version into a selected artifact by inference.
          if (coordinate = label.match(/\A([\w.-]+):([\w.-]+):([^ :,]+)(?: -> ([^ ,]+))?/))
            node['coordinate'] = { 'group' => coordinate[1], 'name' => coordinate[2], 'requested' => coordinate[3], 'selected' => coordinate[4] || coordinate[3] } unless modules.include?(coordinate[1])
          end
          current['nodes'] << node
          current['edges'] << { 'from' => depth.zero? ? 'root' : stack.fetch(depth - 1), 'to' => id }
          stack = stack.take(depth) + [id]
        elsif line.empty? || line == '│' || (!current && !line.start_with?('Dependencies'))
          next # Versioned CLI diagnostics before a graph are retained in raw logs.
        else
          raise Failure, 'Unrecognized dependency graph line'
        end
      end
      raise Failure, 'Dependency graph module coverage differs' unless declared.sort == modules.sort && declared.uniq.size == declared.size
      graphs.each do |graph|
        raise Failure, 'Incomplete dependency graph root' unless graph.values_at('usage', 'scope', 'platforms').all? && !graph['platforms'].empty?
      end
      modules.each do |name|
        roots = graphs.select { |g| g['module'] == name }
        raise Failure, 'Missing main/test compile/runtime graph coverage' unless %w[main test].all? { |usage| %w[compile runtime].all? { |scope| roots.any? { |g| g['usage'] == usage && g['scope'] == scope } } }
      end
      { 'format' => 'toolchain-pretty-graph-v1', 'graphs' => graphs,
        'limitations' => ['Repeated nodes refer to earlier printed branches; no invented expansion', 'Maven dependency resolution is not compiler/Native artifact or Gradle bridge target resolution'] }
    end

    def self.artifacts(root)
      Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).sort.each_with_object({}) do |path, records|
        next unless File.file?(path) && !File.symlink?(path) && path.match?(/\.(?:jar|klib|aar|pom|module|tgz|zip)\z|\/\.flag\z/)
        raise Failure, 'Artifact path escaped owned cache' unless File.realpath(path).start_with?(File.realpath(root) + '/')
        records[path.delete_prefix(root + '/')] = { 'sha256' => Maintenance.file_sha(path), 'bytes' => File.size(path) }
      end
    end

    def self.classify(log, code)
      unsupported_target = clean(log).match?(/ERROR: Platform [A-Za-z0-9]+ is not supported by the library [A-Za-z0-9_.:-]+/)
      # The reviewed CLI can continue compiling another platform after this
      # diagnostic. A nominal zero exit does not establish target compatibility.
      return unsupported_target ? 'failed' : 'passed' if code == 0
      return 'infrastructure' if log.match?(/timed? ?out|timeout|UnknownHost|Connection (?:reset|refused)|Could not (?:GET|HEAD)|HTTP (?:4\d\d|5\d\d)|checksum mismatch|No space left|unable to download|could not download|daemon disappeared|was killed|OutOfMemory/i)
      return 'missing' if log.match?(/SDK (?:location|not found)|SDK is not|license.*not accepted|No (?:available|matching).*simulator|toolchain.*not found|Cannot find.*(?:SDK|JDK)/i)
      return 'failed' if unsupported_target || log.match?(/Compilation failed|compile.*error|(?:^|\n)e: .*\.kt:|tests? failed|\*\* TEST FAILED \*\*|error:.*(?:incompatible|unresolved reference|cannot find|no such module)/i)
      'infrastructure' # An unexplained nonzero exit is not a causal regression.
    end
  end
end
