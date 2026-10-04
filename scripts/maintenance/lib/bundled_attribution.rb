# frozen_string_literal: true

require_relative 'compatibility_report'
require 'rubygems/package'
require 'zlib'
require 'yaml'

module Maintenance
  module BundledAttribution
    CONFIG = 'maintenance-bundled-inputs.json'
    GAPS = %w[source_binary_reproducibility shaded_code native_bundle_internals vulnerable_function_exposure native_tests application_builds clean_clone_sdk_provisioning].freeze

    def self.source_url(path, version)
      raise Failure, 'Unsafe versioned source path' unless path.match?(%r{\A[A-Za-z0-9_./-]+\z}) && !path.split('/').include?('..')
      'https://raw.githubusercontent.com/JetBrains/kotlin-toolchain/v' + version + '/' + path
    end

    def self.identity!(identity)
      raise Failure, 'Invalid bundled artifact identity' unless identity.is_a?(Hash) && identity['kind'] == 'file' && identity['bytes'].is_a?(Integer) && identity['bytes'].positive? && identity['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/)
    end

    def self.config!(config, pin)
      version = config.fetch('toolchain')
      dist = config.fetch('distribution')
      unless config['schema'] == 1 && config['automatic_adoption'] == false && version == '0.13.0' &&
             dist['url'] == "https://packages.jetbrains.team/maven/p/amper/amper/org/jetbrains/kotlin/kotlin-cli/#{version}/kotlin-cli-#{version}-dist.tgz" && dist['sha256'] == pin &&
             dist['bytes'].is_a?(Integer) && dist['bytes'].positive? && dist['classpath_member'] == 'extra/android-integration-gradle-plugin.classpath.txt'
        raise Failure, 'Unreviewed bundled distribution configuration'
      end
      raise Failure, 'Missing bundled attribution declarations' unless config['files'].is_a?(Array) && !config['files'].empty? && config['sources'].is_a?(Array) && config['sources'].any? { |s| s['path'] == 'project.yaml' }
      config['sources'].each do |s|
        raise Failure, 'Invalid source pin' unless s['url'] == source_url(s.fetch('path'), version) && s['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/)
      end
      config['files'].each do |item|
        raise Failure, 'Unsafe bundled member name' unless item['file'].to_s.match?(/\A[A-Za-z0-9_.+-]+\.jar\z/)
        identity!(item.fetch('identity'))
        if item['kind'] == 'maven_reference'
          c = item.fetch('component'); UpgradeGraph.component!(c.merge('kind' => 'maven'))
          url = 'https://repo.maven.apache.org/maven2/' + c['group'].tr('.', '/') + '/' + c['name'] + '/' + c['version'] + '/' + c['name'] + '-' + c['version'] + '.jar'
          raise Failure, 'Unreviewed Maven reference endpoint or classifier' unless item['url'] == url && item['classifier'].nil?
        elsif item['kind'] == 'source_module_correspondence'
          module_name = item.fetch('module').split('/').last
          raise Failure, 'Unreviewed source-module mapping' unless item['url'] == source_url(item['module'] + '/module.yaml', version) &&
            item['metadata_member'] == 'META-INF/' + module_name + '.kotlin_module' && item['source_sha256'].to_s.match?(/\A[0-9a-f]{64}\z/) && item['metadata_sha256'].to_s.match?(/\A[0-9a-f]{64}\z/)
        else
          raise Failure, 'Unknown bundled attribution kind'
        end
      end
      raise Failure, 'Duplicate bundled attribution declarations' unless config['files'].map { |f| f['file'] }.uniq.size == config['files'].size && config['sources'].map { |s| s['path'] }.uniq.size == config['sources'].size
      config
    rescue KeyError, TypeError, NoMethodError
      raise Failure, 'Malformed bundled attribution configuration'
    end

    def self.binding(report, config)
      unless report['state'] == 'checks_passed' && report.dig('binding', 'adapter') == 'compatibility-upstream-build-inputs' && report['bundled_settings_inputs'].is_a?(Hash)
        raise Failure, 'Bundled attribution requires the passing retained-bridge upstream pair'
      end
      candidate = report.fetch('phases').find { |p| p['phase'] == 'candidate' }
      raise Failure, 'Attribution Toolchain differs from executed candidate' unless candidate && candidate.dig('candidate_selection', 'version') == config['toolchain']
      outstanding = report['bundled_settings_inputs']['unassigned'].map { |a| a.slice('name', 'identity') }.sort_by { |a| a['name'] }
      declarations = config['files'].map { |a| { 'name' => a['file'], 'identity' => a['identity'] } }.sort_by { |a| a['name'] }
      raise Failure, 'Reviewed files differ from measured unassigned inputs' unless declarations == outstanding
      { 'original_run_id' => report['run_id'], 'original_result_sha256' => report['result_sha256'], 'original_binding' => report['binding'],
        'producer_sha256' => report['bundled_settings_inputs']['producer_sha256'], 'config_sha256' => Maintenance.digest(config),
        'deriver_sha256' => Maintenance.file_sha(__FILE__) }
    end

    def self.fetch(url, file)
      status = Maintenance.run(['/usr/bin/curl', '-q', '--silent', '--show-error', '--fail', '--location', '--proto', '=https', '--proto-redir', '=https', '--connect-timeout', '10', '--max-time', '120', '--output', file, url],
        cwd: File.dirname(file), env: { 'PATH' => '/usr/bin:/bin', 'HOME' => File.dirname(file) }, log: file + '.log', timeout: 125)
      raise Failure, 'Primary artifact transport failed; no attribution credited' unless status.success? && File.file?(file) && !File.symlink?(file)
    end

    def self.source_packet(spec, file)
      body = File.read(file)
      expected = spec['source_sha256'] || spec.fetch('sha256')
      raise Failure, 'Versioned source bytes differ' unless Digest::SHA256.hexdigest(body) == expected
      { 'url' => spec['url'], 'sha256' => expected, 'body' => body }
    end

    def self.git_identity(root)
      env = { 'PATH' => '/usr/bin:/bin', 'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1', 'GIT_OPTIONAL_LOCKS' => '0' }
      head, status = Open3.capture2(env, '/usr/bin/git', '-C', root, 'rev-parse', 'HEAD', unsetenv_others: true)
      raise Failure, 'Cannot inspect caller HEAD' unless status.success?
      index, status = Open3.capture2(env, '/usr/bin/git', '-C', root, 'ls-files', '--stage', '-v', '-z', unsetenv_others: true)
      raise Failure, 'Cannot inspect caller staged entries' unless status.success?
      { 'head' => head.strip, 'index_sha256' => Digest::SHA256.hexdigest(index) }
    end

    def self.collect(root, report, config, transport: method(:fetch), checkpoint: ->(_receipt) {})
      source = Source.new(root)
      git = git_identity(root)
      receipt = { 'schema' => 1, 'state' => 'collecting', 'binding' => binding(report, config), 'config' => config,
        'collected_at' => Time.now.utc.iso8601, 'sources' => [], 'independent_artifacts' => [], 'archive' => {}, 'caller_source_sha256' => source.public_identity['sha256'],
        'git' => git, 'caller_preservation' => false, 'temporary_downloads_cleaned' => false, 'adoption_authorized' => false }
      checkpoint.call(receipt)
      temp = nil
      begin
        Dir.mktmpdir('mobi-bundled-attribution-') do |dir|
          temp = dir
          dist = config.fetch('distribution'); file = File.join(dir, 'distribution.tgz')
          transport.call(dist['url'], file)
          raise Failure, 'Distribution bytes differ from reviewed pin' unless File.size(file) == dist['bytes'] && Maintenance.file_sha(file) == dist['sha256']
          wanted = report['bundled_settings_inputs'].values_at('matches', 'unassigned').flatten.to_h { |a| ['extra/jars/' + a['name'], { 'file' => a['name'], 'identity' => a['identity'] }] }
          config['files'].each { |item| wanted['extra/jars/' + item['file']] = item }
          records = {}; index = nil
          Zlib::GzipReader.open(file) do |gzip|
            Gem::Package::TarReader.new(gzip) do |tar|
              tar.each do |entry|
                name = entry.full_name
                next unless name == dist['classpath_member'] || wanted.key?(name)
                raise Failure, 'Non-file or duplicate archive evidence member' unless entry.file? && !records.key?(name) && !(name == dist['classpath_member'] && index)
                data = entry.read
                if name == dist['classpath_member']
                  index = data
                else
                  item = wanted[name]; identity = { 'kind' => 'file', 'sha256' => Digest::SHA256.hexdigest(data), 'bytes' => data.bytesize }
                  raise Failure, 'Measured bundled file differs from distribution' unless identity == item['identity']
                  record = { 'member' => name, 'identity' => identity }
                  if item['kind'] == 'source_module_correspondence'
                    jar = File.join(dir, item['file']); File.binwrite(jar, data)
                    meta, _err, status = Open3.capture3('/usr/bin/unzip', '-p', jar, item['metadata_member'])
                    raise Failure, 'Embedded Kotlin module metadata differs' unless status.success? && Digest::SHA256.hexdigest(meta) == item['metadata_sha256']
                    record['metadata_member'] = item['metadata_member']; record['metadata_sha256'] = Digest::SHA256.hexdigest(meta)
                  end
                  records[name] = record
                end
              end
            end
          end
          raise Failure, 'Missing distribution evidence members' unless index && records.keys.sort == wanted.keys.sort
          receipt['archive'] = { 'url' => dist['url'], 'sha256' => dist['sha256'], 'bytes' => dist['bytes'], 'classpath_body' => index,
            'classpath_sha256' => Digest::SHA256.hexdigest(index), 'members' => records.values.sort_by { |a| a['member'] } }
          checkpoint.call(receipt)
          config['sources'].each_with_index do |spec, i|
            file = File.join(dir, "source-#{i}"); transport.call(spec['url'], file)
            receipt['sources'] << source_packet(spec, file); checkpoint.call(receipt)
          end
          config['files'].each_with_index do |spec, i|
            file = File.join(dir, "artifact-#{i}"); transport.call(spec['url'], file)
            if spec['kind'] == 'maven_reference'
              id = { 'kind' => 'file', 'sha256' => Maintenance.file_sha(file), 'bytes' => File.size(file) }
              raise Failure, 'Independent Maven artifact differs from measured bytes' unless id == spec['identity']
              receipt['independent_artifacts'] << { 'url' => spec['url'], 'identity' => id }
            else
              receipt['sources'] << source_packet(spec, file)
            end
            checkpoint.call(receipt)
          end
          source.verify!
          raise Failure, 'Caller HEAD/index changed during attribution' unless git == git_identity(root)
          receipt['caller_preservation'] = true
        end
        receipt['state'] = 'collected'
      rescue Failure, StandardError => error
        receipt['state'] = 'incomplete'; receipt['failure'] = error.is_a?(Failure) ? error.message : 'Attribution producer failed'
      ensure
        receipt['temporary_downloads_cleaned'] = temp && !File.exist?(temp)
        checkpoint.call(receipt)
      end
      receipt
    end

    def self.verify!(receipt, report, config)
      unless receipt['schema'] == 1 && receipt['state'] == 'collected' && receipt['binding'] == binding(report, config) && receipt['config'] == config && receipt['caller_preservation'] == true && receipt['temporary_downloads_cleaned'] == true && receipt['adoption_authorized'] == false
        raise Failure, 'Incomplete or differently bound bundled attribution'
      end
      archive = receipt.fetch('archive'); dist = config['distribution']
      unless archive.slice('url', 'sha256', 'bytes') == dist.slice('url', 'sha256', 'bytes') && Digest::SHA256.hexdigest(archive.fetch('classpath_body')) == archive['classpath_sha256']
        raise Failure, 'Distribution attribution producer differs'
      end
      names = archive['classpath_body'].lines.map(&:strip).reject(&:empty?)
      measured = report['bundled_settings_inputs'].values_at('matches', 'unassigned').flatten.map { |a| a['name'] }.sort
      raise Failure, 'Distribution classpath differs from measured files' unless names.sort == measured && names.uniq.size == names.size
      expected = report['bundled_settings_inputs'].values_at('matches', 'unassigned').flatten.to_h { |a| ['extra/jars/' + a['name'], { 'file' => a['name'], 'identity' => a['identity'] }] }
      config['files'].each { |item| expected['extra/jars/' + item['file']] = item }
      records = archive.fetch('members')
      raise Failure, 'Archive member set differs' unless records.map { |r| r['member'] }.sort == expected.keys.sort
      source_specs = config['sources'] + config['files'].select { |i| i['kind'] == 'source_module_correspondence' }
      sources = receipt.fetch('sources')
      raise Failure, 'Source producer set differs' unless sources.map { |s| s['url'] }.sort == source_specs.map { |s| s['url'] }.sort
      source_specs.each do |s|
        packet = sources.find { |p| p['url'] == s['url'] }; sha = s['source_sha256'] || s['sha256']
        raise Failure, 'Source producer bytes differ' unless packet['sha256'] == sha && Digest::SHA256.hexdigest(packet.fetch('body')) == sha
      end
      project = YAML.safe_load(sources.find { |s| s['url'] == source_url('project.yaml', config['toolchain']) }.fetch('body'))
      third = config['files'].select { |i| i['kind'] == 'maven_reference' }
      raise Failure, 'Independent artifact producer set differs' unless receipt['independent_artifacts'].sort_by { |a| a['url'] } == third.map { |i| { 'url' => i['url'], 'identity' => i['identity'] } }.sort_by { |a| a['url'] }
      identities = records.filter_map do |record|
        item = expected.fetch(record['member']); raise Failure, 'Archive artifact identity differs' unless record['identity'] == item['identity']
        next unless item['kind']
        if item['kind'] == 'source_module_correspondence'
          module_body = sources.find { |s| s['url'] == item['url'] }['body']
          declaration = YAML.safe_load(module_body)
          unless project.fetch('modules').include?(item['module']) && declaration['product'] == 'jvm/lib' && record['metadata_member'] == item['metadata_member'] && record['metadata_sha256'] == item['metadata_sha256']
            raise Failure, 'Source module registration or embedded metadata differs'
          end
        end
        item.merge('evidence_kind' => item['kind'] == 'maven_reference' ? 'independent_maven_artifact_byte_match' : 'pinned_distribution_and_registered_source_module_correspondence')
      end
      queries = third.map { |i| c = i['component']; { 'package' => { 'ecosystem' => 'Maven', 'name' => c['group'] + ':' + c['name'] }, 'version' => c['version'] } }.sort_by { |q| [q['package']['name'], q['version']] }
      { 'schema' => 1, 'state' => 'measured_file_identities_accounted_for', 'binding' => receipt['binding'], 'receipt_sha256' => Maintenance.digest(receipt),
        'measured_file_count' => measured.size, 'file_count' => identities.size, 'independent_maven_count' => third.size, 'source_module_count' => identities.size - third.size, 'files' => identities,
        'queries' => queries, 'candidate_maven_resolution' => 'not_inferred', 'candidate_variant' => 'not_inferred', 'source_binary_reproducibility' => 'unproven',
        'missing_capabilities' => GAPS, 'remediation_verified' => false, 'adoption_authorized' => false }
    rescue KeyError, TypeError, NoMethodError, Psych::Exception
      raise Failure, 'Malformed bundled attribution producer'
    end

    def self.configuration(root)
      path = File.join(root, CONFIG)
      raise Failure, 'Symlinked attribution configuration' if File.symlink?(path)
      config = JSON.parse(File.read(path))
      pins = JSON.parse(File.read(File.join(root, 'maintenance-kotlin-toolchains.json')))
      config!(config, pins.fetch('versions').fetch(config.fetch('toolchain')).fetch('distribution_sha256'))
    end

    def self.report(root, store, id)
      original = CompatibilityReport.read(store, id)
      store.lock(id, create: false) do
        raise Failure, 'Original result changed during attribution replay' unless Maintenance.file_sha(store.path(id, '.result.json')) == original['result_sha256']
        path = File.join(store.path(id), 'bundled-attribution.json')
        raise Failure, 'Symlinked bundled attribution receipt' if File.symlink?(path)
        config = configuration(root)
        receipt = JSON.parse(File.read(path))
        summary = verify!(receipt, original, config)
        result = Marshal.load(Marshal.dump(original))
        result['bundled_file_attribution'] = summary
        result['input_evidence_sha256'] = summary['receipt_sha256']
        result['direct_resolution']['candidate']['advisory_queries']['queries'] = (original['direct_resolution']['candidate']['advisory_queries']['queries'] + summary['queries']).uniq.sort_by { |q| [q['package']['name'], q['version']] }
        result['direct_advisories'] = nil
        result.delete('advisory_comparison')
        result['missing_capabilities'] -= ['bundled_settings_classpath_attribution']
        result['missing_capabilities'] |= GAPS
        provider = File.join(store.path(id), 'bundled-advisory-review.json')
        if File.exist?(provider)
          raise Failure, 'Symlinked bundled advisory receipt' if File.symlink?(provider)
          result['direct_advisories'] = AdvisoryReview.verify!(JSON.parse(File.read(provider)), result)
          baseline = result['baseline_advisories']; candidate = result['direct_advisories']
          complete = [baseline, candidate].all? { |a| a && %w[provider_complete triage_required].include?(a['state']) }
          result['advisory_comparison'] = { 'state' => complete ? 'review_required' : 'incomplete', 'lookup_removed_ids' => complete ? baseline['finding_ids'] - candidate['finding_ids'] : [],
            'lookup_added_ids' => complete ? candidate['finding_ids'] - baseline['finding_ids'] : [], 'lookup_remaining_ids' => complete ? baseline['finding_ids'] & candidate['finding_ids'] : [],
            'scope' => 'named_baseline_reference_and_independent_maven_bytes_only', 'remediation_verified' => false, 'adoption_authorized' => false }
        end
        result
      end
    end
  end
end
