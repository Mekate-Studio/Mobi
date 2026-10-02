# frozen_string_literal: true

require_relative 'interop_experiment'

module Maintenance
  # Used only inside the executor-owned build copy, never an adoption patch.
  class DirectRoundtrip
    KOTLIN_PROBE = 'shared-di/src/MobiIncrementalProbe.kt'
    SWIFT_PROBE = 'ios-app/tests/Maintenance/MobiIncrementalProbeTests.swift'
    attr_reader :manifest

    def initialize(work, fixtures)
      @work = work
      @experiment = InteropExperiment.new(work, fixtures)
      @original = Dir.glob(File.join(work, '**', '*'), File::FNM_DOTMATCH).sort.each_with_object({}) do |path, files|
        next if %w[. ..].include?(File.basename(path)) || File.directory?(path) && !File.symlink?(path)
        relative = path.delete_prefix(work + '/')
        check_path!(relative)
        raise Failure, 'Roundtrip input is not a regular file' unless File.file?(path)
        files[relative] = { 'content' => File.binread(path), 'mode' => File.stat(path).mode & 0o777 }
      end
      @original_manifest = @original.transform_values { |entry| identity(entry['content'], entry['mode']) }
      @restored = false
    end

    def identity(content, mode)
      { 'sha256' => Digest::SHA256.hexdigest(content), 'executable' => (mode & 0o111) != 0 }
    end

    def check_path!(relative)
      parts = relative.split('/')
      raise Failure, 'Roundtrip path is symlinked' if parts.each_index.any? { |i| File.symlink?(File.join(@work, *parts.take(i + 1))) }
    end

    def prepare!
      raise Failure, 'Roundtrip probe already exists' if [KOTLIN_PROBE, SWIFT_PROBE].any? { |p| File.exist?(File.join(@work, p)) }
      @experiment.prepare!
      @experiment.write(KOTLIN_PROBE, "package studio.mekate.mobi.di\n\nobject MobiIncrementalProbe {\n    fun value(): String = \"slice10-before\"\n}\n")
      @experiment.write(SWIFT_PROBE, "@preconcurrency import KotlinModules\nimport Testing\n\n@Suite(\"Maintenance incremental consumer\")\nstruct MobiIncrementalProbeTests {\n    @Test\n    func kotlinChangeReachesSwift() {\n        #expect(MobiIncrementalProbe.shared.value() == \"slice10-before\")\n    }\n}\n")
      @manifest = @original_manifest.reject { |p, _| p.start_with?('gradle-bridge/') }
      @experiment.changes.each do |change|
        next unless change['after_sha256']
        path = File.join(@work, change['path'])
        @manifest[change['path']] = identity(File.binread(path), File.stat(path).mode)
      end
      @manifest = @manifest.sort.to_h
      @expected_modes = @manifest.keys.to_h { |p| [p, File.stat(File.join(@work, p)).mode & 0o777] }
      verify!
      @experiment.changes
    end

    def verify_absence!
      @experiment.verify_absence! unless @restored
    end

    def verify!
      verify_absence!
      @manifest.each do |relative, expected|
        check_path!(relative)
        file = File.join(@work, relative)
        unless File.file?(file) && identity(File.binread(file), File.stat(file).mode) == expected && (File.stat(file).mode & 0o777) == @expected_modes.fetch(relative)
          raise Failure, 'Roundtrip authored input drifted'
        end
      end
      authored = Dir.glob(File.join(@work, '*/{src,src@*,test,test@*,tests}/**/*.{kt,kts,swift}'))
      authored += Dir.glob(File.join(@work, 'ios-app/Dependencies/{Sources,Tests}/**/*.swift'))
      raise Failure, 'Roundtrip added unexpected authored source' unless (authored.map { |p| p.delete_prefix(@work + '/') } - @manifest.keys).empty?
    end

    def mutate!
      raise Failure, 'Roundtrip already restored' if @restored
      verify!
      before = Maintenance.digest(@manifest)
      changes = [KOTLIN_PROBE, SWIFT_PROBE].map do |relative|
        content = File.read(File.join(@work, relative))
        raise Failure, 'Unexpected incremental probe preimage' unless content.scan('slice10-before').size == 1
        { 'path' => relative, 'before_sha256' => @manifest.fetch(relative)['sha256'], 'content' => content.sub('slice10-before', 'slice10-after') }
      end
      changes.each do |change|
        @experiment.write(change['path'], change['content'])
        @manifest[change['path']] = identity(change['content'], @expected_modes.fetch(change['path']))
        change['after_sha256'] = @manifest[change['path']]['sha256']
        change.delete('content')
      end
      verify!
      { 'schema' => 1, 'before_source_sha256' => before, 'after_source_sha256' => Maintenance.digest(@manifest),
        'changes' => changes, 'cache_policy' => 'preserved', 'generated_products_removed' => false, 'adoption_authorized' => false }
    end

    def restore!
      raise Failure, 'Roundtrip already restored' if @restored
      verify! # Validate every authored preimage before deleting or restoring anything.
      product_root = File.join(@work, 'build')
      raise Failure, 'Roundtrip generated output is symlinked' if File.symlink?(product_root)
      raise Failure, 'Roundtrip generated output is not a directory' if File.exist?(product_root) && !File.directory?(product_root)
      cleared = File.directory?(product_root) ? ['build'] : []
      FileUtils.remove_entry_secure(product_root) unless cleared.empty?
      (@manifest.keys - @original.keys).each { |relative| File.unlink(File.join(@work, relative)) }
      @original.each do |relative, original|
        next if @manifest[relative] == @original_manifest[relative] && @expected_modes[relative] == original['mode']
        check_path!(relative)
        path = File.join(@work, relative)
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, original['content']); File.chmod(original['mode'], path)
      end
      @manifest = @original_manifest.dup
      @expected_modes = @original.transform_values { |entry| entry['mode'] }
      @restored = true
      verify!
      { 'schema' => 1, 'original_source_sha256' => Maintenance.digest(@original_manifest), 'restored_source_sha256' => Maintenance.digest(@manifest),
        'generated_products_cleared' => cleared, 'fixture_additions_removed' => true, 'bridge_restored' => true, 'adoption_authorized' => false }
    end
  end
end
