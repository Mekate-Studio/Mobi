# frozen_string_literal: true

require_relative 'delivery'

module Maintenance
  module SwiftExport
    module Assemble
      def self.copy(from, to)
        FileUtils.mkdir_p(File.dirname(to))
        raise Failure, 'Delivery member copy failed' unless system('/bin/cp', '-cR', from, to)
      end

      def self.call(descriptor, inputs, output)
        descriptor.inspection # Verify selected source cohorts before assembly.
        inputs.fetch('files').each { |f| raise Failure, 'Producer/native input drift' unless Maintenance.file_sha(f['path']) == f['sha256'] }
        seed = File.join(output, 'delivery-source')
        Dir.mkdir(seed)
        generated = inputs.fetch('phases').fetch(ENV.fetch('MOBI_PHASE'))
        modules = generated.fetch('modules').map do |m|
          value = m.dup
          %w[swift header kotlin].each do |key|
            next if m[key].to_s.empty?
            relative = File.join('generated', m['name'], File.basename(m[key]))
            copy(m[key], File.join(seed, relative))
            value[key] = relative
          end
          value['dependencies'] = m['dependencies'].to_s.split(',')
          if m['kind'] == 'bridge'
            value['modulemap'] = File.join('generated', m['name'], m['bridge'] + '.modulemap')
            File.write(File.join(seed, value['modulemap']), "module #{m['bridge']} { header \"#{File.basename(value['header'])}\" export * }\n")
          end
          value
        end
        copy(generated['runtime_headers'], File.join(seed, 'kotlin_runtime'))
        copy(generated['native_archive'], File.join(seed, 'libMobiCompositionNative.a'))
        copy(inputs['package_products'], File.join(seed, 'NativeProducts'))
        inputs['resource_bundles'].each { |p| copy(p, File.join(seed, 'NativeResources', File.basename(p))) }
        sources = descriptor.data['native']['sources'].map do |p|
          name = File.join('NativeSources', File.basename(p).delete_suffix('.template'))
          copy(Descriptor.safe(descriptor.root, p), File.join(seed, name))
          name
        end
        fixtures = inputs.fetch('materialized_fixtures')
        %w[Aliases.swift offline-style.json AccessibilityBootstrap.swift.txt].each { |n| copy(File.join(fixtures, n), File.join(seed, 'NativeSources', n)) }
        copy(inputs['production_plist'], File.join(seed, 'App-Info.plist'))
        copy(inputs['production_assets'], File.join(seed, 'Assets.xcassets'))
        provenance = %w[kotlin native].to_h do |name|
          path = File.join(output, name + '-cold-report.json')
          report = JSON.parse(File.read(path))
          [name, { 'report_sha256' => Maintenance.file_sha(path), 'seed_operations' => 0, 'production' => 'fresh_owned_source_build',
                   'host_cache_reads' => 'tool_and_publisher_bootstrap_may_consult_host_caches; explicit_publisher_checksums_verified',
                   'commands' => report.fetch('commands').map { |c| c.reject { |k, _| k == 'argv' } } }]
        end
        graph = { 'schema' => 1, 'input_identity' => Maintenance.digest([descriptor.inspection['identity'], inputs.fetch('tool_tuple'), inputs.fetch('enum_variant')]), 'tool_tuple' => inputs['tool_tuple'], 'profile' => descriptor.profile,
                  'repository_policy' => descriptor.repository_policy, 'target' => descriptor.data['target'], 'wire_schema' => descriptor.data['wire_schema'],
                  'expected_modules' => inputs['expected_modules'], 'modules' => modules, 'module_modes' => descriptor.modes(modules.map { |m| m['name'] }),
                  'consumer_mode' => '6', 'runtime_headers' => 'kotlin_runtime', 'archive' => 'libMobiCompositionNative.a',
                  'archive_sha256' => generated['native_archive_sha256'], 'aliases' => 'NativeSources/Aliases.swift', 'provenance' => provenance,
                  'runtime_settings' => descriptor.data['runtime_settings'],
                  'enum_variant' => inputs.fetch('enum_variant'),
                  'native' => { 'sources' => sources, 'products' => ['NativeProducts/MapLibre.framework'] + Dir.glob(File.join(seed, 'NativeProducts', '*.o')).map { |p| p.delete_prefix(seed + '/') },
                                'macros' => descriptor.data['native']['macros'].map { |n| 'NativeProducts/macros/' + n },
                                'resources' => inputs['resource_bundles'].map { |p| 'NativeResources/' + File.basename(p) },
                                'plist' => 'App-Info.plist', 'assets' => 'Assets.xcassets', 'offline_style' => 'NativeSources/offline-style.json' } }
        if inputs['app_configuration']
          copy(File.join(fixtures, 'pilot-runtime-settings.json'), File.join(seed, 'NativeSources/pilot-runtime-settings.json'))
          graph['app_configuration'] = inputs['app_configuration']
        end
        graph['expected_members'] = (Delivery.files(seed).keys + ['graph.json']).sort
        File.write(File.join(seed, 'graph.json'), JSON.pretty_generate(graph) + "\n")
        [seed, Delivery.seal(seed)]
      end

      def self.consumer_inputs(delivery, phase)
        identity = Delivery.verify(delivery)
        graph = Delivery.validate(delivery)
        modules = graph['modules'].map do |m|
          value = m.dup
          %w[swift header kotlin].each { |k| value[k] = File.join(delivery, m[k]) unless m[k].to_s.empty? }
          value['dependencies'] = m['dependencies'].join(',')
          value
        end
        generated = { 'modules' => modules, 'native_archive' => File.join(delivery, graph['archive']), 'native_archive_sha256' => graph['archive_sha256'], 'runtime_headers' => File.join(delivery, graph['runtime_headers']) }
        { 'source_sha256' => graph['input_identity'], 'profile' => graph['profile'], 'phases' => { phase => generated },
          'files' => Delivery.files(delivery).map { |p, value| { 'path' => File.join(delivery, p), 'sha256' => value['sha256'] } },
          'package_products' => File.join(delivery, 'NativeProducts'), 'sources' => graph['native']['sources'].map { |p| File.basename(p) },
          'resource_bundles' => graph['native']['resources'].map { |p| File.join(delivery, p) },
          'production_plist' => File.join(delivery, graph['native']['plist']), 'production_assets' => File.join(delivery, graph['native']['assets']),
          'delivery_identity' => identity, 'app_configuration' => graph.fetch('app_configuration', {}) }
      end
    end
  end
end
