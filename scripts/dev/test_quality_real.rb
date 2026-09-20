# frozen_string_literal: true

# Optional integration probes using already installed analyzers. No downloads.
require_relative 'test_quality'

Dir.mktmpdir('mobi-quality-real-') do |temp|
  fixture = QualityTest::Fixture.new(temp)
  fixture.env['PATH'] = ENV.fetch('PATH') # Select installed tools, not fixture tools.
  fixture.new_module
  swift = 'ios-app/Dependencies/Sources/PackageValue.swift'
  fixture.write(swift, "public enum PackageValue {\n    public static let answer = 42\n}\n")
  fixture.stage
  fixture.pass
  puts 'PASS real-tool baseline in isolated repository'

  fixture.write('feature/src/New.kt', "class New{val answer=42}\n")
  fixture.reject(/ktlint failed/, 'static')
  fixture.stage
  fixture.reject(/ktlint failed/)
  fixture.write('feature/src/New.kt', "class New {\n    val answer = 42\n}\n")
  fixture.stage
  fixture.pass
  puts 'PASS new Kotlin file: manual and staged violation rejected; repair passes'

  fixture.write(swift, "public enum PackageValue {\n    public static let x = 42\n}\n")
  fixture.stage
  fixture.reject(/swiftlint failed/)
  fixture.write(swift, "public enum PackageValue {\n    public static let answer = 42\n}\n")
  fixture.stage
  fixture.pass
  puts 'PASS Swift package source: SwiftLint violation rejected; repair passes'

  crowded = 'feature-new/src@ios/Crowded.kt'
  fixture.write(crowded, <<~KOTLIN)
    fun crowded(
        first: Int,
        second: Int,
        third: Int,
        fourth: Int,
        fifth: Int,
        sixth: Int,
        seventh: Int,
        eighth: Int,
        ninth: Int,
    ) = first + second + third + fourth + fifth + sixth + seventh + eighth + ninth
  KOTLIN
  fixture.stage
  fixture.reject(/detekt failed/)
  fixture.write(crowded, "fun crowded(value: Int) = value\n")
  fixture.stage
  fixture.pass
  puts 'PASS new module platform root: detekt violation rejected; repair passes'

  hook = File.binread(File.join(fixture.root, '.githooks/pre-commit'))
  fixture.write('.githooks/pre-commit', hook + "\necho $quality_missing_quote\n")
  fixture.stage
  fixture.reject(/shellcheck failed/)
  fixture.write('.githooks/pre-commit', hook)
  fixture.stage
  fixture.pass
  puts 'PASS shell hook: ShellCheck violation rejected; repair passes'

  # Actual analyzer parsing, beyond the fake-tool argv contract.
  ["space name", "tab\tname", "new\nline", '-leading'].each do |name|
    fixture.write("feature-new/test@iosSimulatorArm64/#{name}.kt", "// Filename probe\n")
    fixture.write("ios-app/Dependencies/#{name}.swift", "// Filename probe\n")
    fixture.write("scripts/#{name}.sh", "#!/bin/sh\ntrue\n")
  end
  fixture.stage
  output = fixture.reject(/ktlint failed/)
  ["space name", "tab\tname", "new\nline", '-leading'].each do |name|
    QualityTest.assert(output.include?("File name '#{name}.kt'"), "Missing filename diagnostic for #{name.inspect}")
    FileUtils.rm(File.join(fixture.root, "feature-new/test@iosSimulatorArm64/#{name}.kt"))
  end
  fixture.stage
  fixture.pass
  puts 'PASS unusual Kotlin filenames receive style diagnostics; Swift and shell filenames pass unchanged'
end
