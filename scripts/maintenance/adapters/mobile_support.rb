# frozen_string_literal: true

require_relative '../lib/support_policy'
require 'yaml'
require 'rubygems/version'

module Maintenance
  class MobileSupport
    INPUTS = %w[maintenance-support-policy.json maintenance-platform-releases.json].freeze
    ANDROID = 'android-app/module.yaml'
    PACKAGE = 'ios-app/Dependencies/Package.swift'
    XCODE = 'ios-app/module.xcodeproj/project.pbxproj'
    CONFIGURATION = /^\t\t([A-F0-9]+) \/\* (Debug|Release) \*\/ = \{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = \{\n(.*?)^\t\t\t\};\n\t\t\tname = \2;\n\t\t\};/m
    FLOOR = /^\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = "?(\d+(?:\.\d+)?)"?;$/

    def initialize(root)
      @root = root
    end

    def read(path)
      File.read(File.join(@root, path), encoding: 'UTF-8')
    end

    def configurations(text)
      rows = text.scan(CONFIGURATION)
      raise Failure, 'Unsupported Xcode configuration coverage; review the mobile adapter' unless rows.size == 6 && rows.map(&:first).uniq.size == 6 && rows.count { |r| r[2].include?('SDKROOT = iphoneos;') } == 4
      rows.map do |id, name, body|
        values = body.scan(FLOOR).flatten
        raise Failure, 'Ambiguous or conditional Xcode deployment setting' unless body.scan('IPHONEOS_DEPLOYMENT_TARGET').size == values.size && values.size <= 1
        { 'id' => id, 'configuration' => name, 'minimum' => values.first, 'state' => values.empty? ? 'implicit' : 'explicit' }
      end
    end

    def declarations
      android = YAML.safe_load(read(ANDROID)).fetch('settings').fetch('android')
      raise Failure, 'Unsupported Android SDK declarations' unless %w[minSdk compileSdk targetSdk].all? { |key| android[key].is_a?(Integer) }
      package = read(PACKAGE).scan(/\.iOS\((?:\.v(\d+)|"(\d+(?:\.\d+)?)")\)/).map { |a, b| a || b }
      raise Failure, 'Unsupported Swift package minimum' unless package.size == 1
      { 'android' => android.slice('minSdk', 'compileSdk', 'targetSdk'), 'swift_package_minimum' => package.first,
        'xcode_configurations' => configurations(read(XCODE)) }
    rescue KeyError, Psych::Exception
      raise Failure, 'Incomplete mobile declarations'
    end

    def assess(source: nil, now: Time.now.utc)
      paths = INPUTS + [ANDROID, PACKAGE, XCODE]
      source ||= Source.new(@root)
      result = SupportPolicy.new(JSON.parse(read(INPUTS[0])), JSON.parse(read(INPUTS[1])), now: now).assess
      declared = declarations
      result['declarations'] = declared
      result['source'] = source.public_identity
      result['inputs'] = paths.to_h { |path| [path, source.files.fetch(path).fetch('sha256')] }
      result['decision_requirements'] = JSON.parse(read(INPUTS[0])).fetch('decisions_required_for')
      drift = []
      if result['state'] == 'assessed'
        ios = result['platforms'].fetch('ios')
        android = result['platforms'].fetch('android').fetch('proposed_minimum')
        unless ios['proposed_minimum'] == ios['proposed_major'].to_s + '.0' && android.is_a?(Integer) && android.positive?
          result['state'] = 'incomplete'
          result['blockers'] = ['invalid_mobile_minimum_mapping']
        end
      end
      if result['state'] == 'assessed'
        ios = result['platforms'].fetch('ios').fetch('proposed_minimum').to_s
        android = result['platforms'].fetch('android').fetch('proposed_minimum').to_i
        drift << 'android_app_minimum' unless declared['android']['minSdk'] == android
        drift << 'swift_package_minimum' unless Gem::Version.new(declared['swift_package_minimum']) == Gem::Version.new(ios)
        drift << 'xcode_minimum' unless declared['xcode_configurations'].all? { |row| row['minimum'] && Gem::Version.new(row['minimum']) == Gem::Version.new(ios) }
        result['state'] = 'requires_decision' unless drift.empty?
        result['impact'] = { 'android_excludes_api_below' => android, 'ios_excludes_versions_below' => ios,
                             'android_compile_target_unchanged' => true, 'bridge_retirement_authorized' => false }
        if android > declared['android']['compileSdk'] || android > declared['android']['targetSdk']
          result['state'] = 'incomplete'
          result['blockers'] = ['minimum_exceeds_declared_android_compile_or_target_sdk']
        end
      end
      result['drift'] = drift
      result['decision_required'] = result['state'] == 'requires_decision'
      source.verify!
      result
    end

    def edits(source)
      assessment = assess(source: source)
      raise Failure, 'Support assessment is incomplete; refresh primary evidence or resolve declarations' if assessment['state'] == 'incomplete'
      ios = assessment['platforms']['ios']['proposed_minimum'].to_s
      android = assessment['platforms']['android']['proposed_minimum'].to_i
      texts = {}
      text = read(ANDROID)
      raise Failure, 'Ambiguous Android minimum edit' unless text.scan(/^    minSdk: \d+$/).size == 1
      texts[ANDROID] = text.sub(/^    minSdk: \d+$/, '    minSdk: ' + android.to_s)
      texts[PACKAGE] = read(PACKAGE).sub(/\.iOS\((?:\.v\d+|"\d+(?:\.\d+)?")\)/, '.iOS("' + ios + '")')
      texts[XCODE] = read(XCODE).gsub(CONFIGURATION) do |block|
        if block.match?(FLOOR)
          block.sub(FLOOR, "\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = #{ios};")
        else
          block.sub("\t\t\tbuildSettings = {\n", "\t\t\tbuildSettings = {\n\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = #{ios};\n")
        end
      end
      texts.map do |path, content|
        before = source.files.fetch(path).fetch('sha256')
        raise Failure, 'Support input changed after capture' unless Maintenance.file_sha(File.join(@root, path)) == before
        after = Digest::SHA256.hexdigest(content)
        next if before == after
        { 'path' => path, 'before_sha256' => before, 'content' => content, 'after_sha256' => after }
      end.compact
    end
  end
end
