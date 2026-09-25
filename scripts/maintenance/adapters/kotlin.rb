# frozen_string_literal: true

require_relative '../lib/core'
require_relative '../../dev/quality'

module Maintenance
  class Kotlin
    attr_reader :components, :coverage, :resolved_inputs

    def initialize(root, files, native, config)
      @root, @files, @native, @config = root, files, native, config
      @components, @coverage, @resolved_inputs = [], [], []
      Array(@config['packageRules']).select { |rule| rule.key?('allowedVersions') }.each do |rule|
        supported = (rule.keys - %w[description matchDatasources matchPackageNames allowedVersions]).empty? &&
                    rule['allowedVersions'].is_a?(String) && !rule['allowedVersions'].empty? &&
                    rule['matchPackageNames'].is_a?(Array) && !rule['matchPackageNames'].empty? &&
                    rule['matchPackageNames'].all? { |pattern| pattern.is_a?(String) && (pattern.start_with?('/') && pattern.end_with?('/') || !pattern.match?(/[!*?]/)) } &&
                    (!rule.key?('matchDatasources') || rule['matchDatasources'].is_a?(Array) && !rule['matchDatasources'].empty? && rule['matchDatasources'].all? { |name| name.is_a?(String) && name.match?(/\A[a-z][a-z0-9-]*\z/) })
        raise Failure, 'Unsupported conditional ceiling rule; review the inventory adapter' unless supported
      end
    end

    def read(path)
      raise Failure, "Inventory input is absent from source identity: #{path}" unless @files.key?(path)
      File.read(File.join(@root, path))
    end

    def add(name, version, path, kind, **details)
      component = { 'name' => name, 'version' => version, 'source' => path, 'kind' => kind }.merge(details.transform_keys(&:to_s))
      component['ceilings'] = Array(@config['packageRules']).map do |rule|
        next unless rule['allowedVersions']
        datasource = component['datasource'] || { 'Maven' => 'maven', 'npm' => 'npm', 'RubyGems' => 'rubygems' }[component['ecosystem']]
        next if rule['matchDatasources'] && !rule['matchDatasources'].include?(datasource)
        matches = Array(rule['matchPackageNames']).any? do |pattern|
          pattern.start_with?('/') && pattern.end_with?('/') ? Regexp.new(pattern[1...-1]).match?(name) : pattern == name
        end
        rule['allowedVersions'] if matches
      end.compact
      component['id'] = Maintenance.digest(component)
      @components << component unless @components.any? { |c| c['id'] == component['id'] }
      component
    end

    def row(id, state, reason, required: true)
      @coverage << { 'id' => id, 'state' => state, 'reason' => reason, 'required' => required }
    end

    def resolved(id, paths, records)
      @resolved_inputs << { 'id' => id, 'sha256' => Maintenance.digest(paths.sort.to_h { |p| [p, @files.fetch(p)] }), 'packages' => records }
    end

    def inventory
      @native.fetch('managers').each do |manager, entries|
        entries.each do |entry|
          path = entry.fetch('file'); read(path)
          entry['dependencies'].each do |dep|
            add(dep['depName'] || dep['packageName'], dep['currentValue'] || dep['lockedVersion'], path, 'declared', manager: manager, datasource: dep['datasource'], locked_version: dep['lockedVersion'], skip_reason: dep['skipReason'], dep_type: dep['depType'])
          end
        end
        row("native:#{manager}", 'complete', "#{entries.size} files extracted; declarations are not resolved graphs", required: false)
      end
      expected = {
        'bundler' => /(?:^|\/)Gemfile$/,
        'dockerfile' => /(?:^|\/)Dockerfile$/,
        'gradle' => /(?:\.gradle(?:\.kts)?|\.versions\.toml|gradle\.properties)$/,
        'gradle-wrapper' => /gradle-wrapper\.properties$/,
        'swift' => /(?:^|\/)Package\.swift$/,
        'npm' => /(?:^|\/)package\.json$/,
        'ruby-version' => /(?:^|\/)\.ruby-version$/,
        'github-actions' => %r{\A\.github/workflows/.*\.ya?ml$}
      }
      expected.each do |manager, pattern|
        paths = @files.keys.grep(pattern)
        next if paths.empty?
        entries = @native['managers'].fetch(manager, [])
        row("missing-manager:#{manager}", 'incomplete', 'Expected manager produced no extraction') if entries.empty?
        (paths - entries.map { |entry| entry['file'] }).each do |path|
          row("missing-native-file:#{path}", 'incomplete', "#{manager} did not report this manifest; empty declarations require explicit review")
        end
      end
      resolved_config = @native['resolved_repository_config']
      preset_ceilings = resolved_config && Array(resolved_config['packageRules']).select { |rule| rule.key?('allowedVersions') } - Array(@config['packageRules'])
      if !preset_ceilings || !preset_ceilings.empty?
        row('policy:resolved-preset-rules', 'incomplete', 'Bundled preset constraints are captured but not evaluated by the limited local policy; native candidate-policy integration remains required')
      end
      modules
      xcode
      locks
      tools
      environment
      row('resolved:kotlin-toolchain-targets', 'incomplete', 'Effective Android/Native/Compose/stdlib/plugin variants, edges and artifacts require versioned Toolchain introspection; declarations are insufficient')
      row('resolved:gradle-bridge-targets', 'incomplete', 'Bridge compiler/plugin/native resolved variants and artifact digests have not been captured')
      row('advisories:all-resolved-inputs', 'incomplete', 'No advisory lookup is performed by extraction; use fresh exact-input evidence', required: false)
      { 'adapter' => 'kotlin', 'modules' => @module_names, 'components' => @components.sort_by { |c| [c['source'], c['name'].to_s, c['kind']] }, 'coverage' => @coverage, 'resolved_inputs' => @resolved_inputs }
    end

    def modules
      graph = Dir.chdir(@root) { Quality::ModuleGraph.new }
      @module_names = graph.modules
      (@files.keys.grep(%r{(?:^|/)module\.yaml$}) - graph.modules.map { |name| name + '/module.yaml' }).each { |path| row('undeclared-module:' + path, 'incomplete', 'Module manifest is not declared in project.yaml') }
      graph.modules.each do |name|
        path = name + '/module.yaml'; read(path)
        data = graph.configs.fetch(name)
        walk = lambda do |value, keys|
          case value
          when Hash then value.each { |key, item| walk.call(item, keys + [key]) }
          when Array then value.each { |item| walk.call(item, keys) }
          when String
            if value.match?(/\A[A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+:[^\s]+\z/)
              group, artifact, version = value.split(':', 3)
              add("#{group}:#{artifact}", version, path, 'declared', settings_path: keys.join('.'), ecosystem: 'Maven')
            elsif keys.last.to_s.match?(/compileSdk|targetSdk|minSdk|jvmTarget|languageVersion/) || keys.include?('compose')
              add(keys.join('.'), value, path, 'environment-constraint')
            end
          when Integer
            add(keys.join('.'), value.to_s, path, 'environment-constraint') if keys.last.to_s.match?(/Sdk|jvmTarget/)
          end
        end
        walk.call(data, [])
        row("module:#{name}", 'complete', 'Declared module, dependency lists and compiler-plugin settings inspected', required: false)
      end
      wrapper = read('kotlin')
      version = wrapper[/^kotlin_cli_version=(\S+)/, 1]
      checksum = wrapper[/^kotlin_cli_sha256=([0-9a-f]{64})$/, 1]
      raise Failure, 'Unsupported Kotlin Toolchain wrapper identity' unless version && checksum
      add('Kotlin Toolchain', version, 'kotlin', 'tool', artifact_sha256: checksum, stability: 'alpha')
      path = 'scripts/ci/lib/android_generated_gradle.sh'
      if @files.key?(path)
        version = read(path)[/ANDROID_GENERATED_GRADLE_VERSION:-([^}]+)/, 1]
        add('delegated Android Gradle fallback', version, path, 'tool', effective_version: 'unresolved')
      end
    end

    def xcode
      @files.keys.grep(/project\.pbxproj$/).each do |path|
        text = read(path)
        section = text[%r{/\* Begin XCRemoteSwiftPackageReference section \*/(.*?)/\* End XCRemoteSwiftPackageReference section \*/}m, 1]
        next unless section
        entries = section.scan(/isa = XCRemoteSwiftPackageReference;\s*repositoryURL = "([^"]+)";\s*requirement = \{\s*kind = (\w+);\s*(version|minimumVersion|revision|branch) = "?([^;"\s]+)"?;\s*\};/m)
        raise Failure, "Unsupported Xcode package declaration: #{path}" unless entries.size == section.scan('isa = XCRemoteSwiftPackageReference;').size
        entries.each do |url, kind, key, version|
          add(url, version, path, 'declared', ecosystem: 'SwiftURL', requirement: kind, version_field: key, repository: url)
        end
        text.scan(/(IPHONEOS_DEPLOYMENT_TARGET|SWIFT_VERSION|SDKROOT) = ([^;]+);/).uniq.each do |key, value|
          add(key, value, path, 'environment-constraint')
        end
        row('xcode-packages:' + path, 'complete', "#{entries.size} Xcode package declarations inspected separately from Package.swift", required: false)
      end
    end

    def locks
      @files.keys.grep(/(?:^|\/)Package\.resolved$/).each do |path|
        data = JSON.parse(read(path))
        raise Failure, "Unsupported Swift lock format: #{path}" unless data['version'] == 3 && data['pins'].is_a?(Array)
        records = data['pins'].map do |pin|
          state = pin.fetch('state')
          add(pin.fetch('identity'), state['version'], path, 'locked', ecosystem: 'SwiftURL', repository: pin.fetch('location'), revision: state.fetch('revision'), relationship: @components.any? { |c| c['kind'] == 'declared' && [c['repository'], c['name']].compact.any? { |name| name.sub(/\.git$/, '') == pin['location'].sub(/\.git$/, '') } } ? 'direct' : 'transitive')
        end
        resolved('swift:' + path, [path], records)
        row('swift-lock:' + path, 'complete', "#{records.size} locked versions/revisions; dependency edges absent", required: false)
        row('swift-graph-edges:' + path, 'incomplete', 'Package.resolved has pins but no target/variant dependency edges')
      end
      @files.keys.grep(/(?:^|\/)Gemfile\.lock$/).each do |path|
        text = read(path)
        raise Failure, 'Git/path gem resolution is not yet supported' if text.match?(/^(GIT|PATH)$/)
        section = text.split(/^PLATFORMS$/).first
        direct = text.split(/^DEPENDENCIES$/).last.to_s.split(/^[A-Z ]+$/).first.to_s.scan(/^  ([\w.-]+)/).flatten
        records = section.scan(/^    ([\w.-]+) \(([^)]+)\)\n((?:      [^\n]+\n)*)/).map do |name, version, children|
          edges = children.scan(/^      ([\w.-]+)(?: \(([^)]+)\))?/).to_h
          add(name, version, path, 'locked', ecosystem: 'RubyGems', relationship: direct.include?(name) ? 'direct' : 'transitive', dependencies: edges)
        end
        raise Failure, "No gems parsed from #{path}" if records.empty?
        resolved('rubygems:' + path, [path], records)
        row('gem-lock:' + path, 'complete', "#{records.size} locked gem versions; effective installed platforms unverified", required: false)
        row('gem-platforms:' + path, 'incomplete', 'Lock constraints are captured; effective installed platform and artifact identities require rehearsal')
        add('bundler', text[/BUNDLED WITH\s+(\S+)/, 1], path, 'tool')
      end
      @files.keys.grep(/(?:^|\/)package-lock\.json$/).each do |path|
        data = JSON.parse(read(path))
        raise Failure, "Unsupported npm lock: #{path}" unless data['lockfileVersion'] == 3 && data['packages'].is_a?(Hash)
        records = data['packages'].reject { |key, _| key.empty? }.map do |location, item|
          add(item['name'] || location.split('node_modules/').last, item.fetch('version'), path, 'locked', ecosystem: 'npm', relationship: data['packages'].fetch('').fetch('dependencies', {}).key?(location.delete_prefix('node_modules/')) ? 'direct' : 'transitive', location: location, integrity: item['integrity'], optional: item['optional'] == true, dependencies: item.fetch('dependencies', {}))
        end
        resolved('npm:' + path, [path], records)
        row('npm-lock:' + path, 'complete', "#{records.size} package entries with integrity and dependency constraints; installation subset is platform-specific", required: false)
      end
    end

    def tools
      %w[quality-tools.json maintenance-tools.json].each do |path|
        next unless @files.key?(path)
        data = JSON.parse(read(path))
        visit = lambda do |item, names|
          if item.is_a?(Hash)
            add(names.join('/'), item['version'], path, 'pinned-tool-artifact', url: item['url'], artifact_sha256: item['sha256']) if item['url'] && item['sha256']
            item.each { |key, value| visit.call(value, names + [key]) }
          elsif item.is_a?(Array)
            item.each_with_index { |value, index| visit.call(value, names + [index.to_s]) }
          end
        end
        visit.call(data, [])
        %w[node_version npm_version renovate_version].each { |key| add(key, data[key], path, 'tool') if data[key] }
      end
      add('Swift language declaration', read('.swift-version').strip, '.swift-version', 'environment-constraint') if @files.key?('.swift-version')
    end

    def environment
      @files.keys.select { |p| p.start_with?('.github/workflows/') && p.end_with?('.yml', '.yaml') }.each do |path|
        read(path).scan(/^\s*runs-on:\s*(.+)$/).flatten.each { |value| add('GitHub runner', value, path, 'floating-environment') }
      end
      if @files.key?('Dockerfile')
        read('Dockerfile').scan(/^ENV (ANDROID_\w+)="?([^"\s]+)"?$/).each { |name, value| add(name, value, 'Dockerfile', 'environment-constraint') }
        read('Dockerfile').scan(%r{https://dl\.google\.com/android/repository/([^\s]+\.zip)}).flatten.each { |name| add('Android command-line tools', name, 'Dockerfile', 'download-without-checksum') }
        row('image-os-packages', 'incomplete', 'Base image tag, apt packages and SDK platform-tools are not digest/version locked')
      end
      row('host-toolchains', 'incomplete', 'Declared Java/SDK/Swift/runner settings are not effective installed Xcode, Kotlin compiler or SDK identities')
    end
  end
end
