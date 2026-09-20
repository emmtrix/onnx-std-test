#!/usr/bin/env ruby
# frozen_string_literal: true

# Gate a Metanorma build on the severity of the diagnostics it reported.
#
#   scripts/check-errors.rb <err.html> [max-severity]
#
# Metanorma writes its diagnostics to <document>.err.html as a table with one
# `<tr class="severityN">` per diagnostic, where N is 0 = fatal, 1 = error,
# 2 = warning, 3 = informational. Exits non-zero if any diagnostic is of
# severity `max-severity` or worse (that is, numerically less than or equal).

report = ARGV[0] or abort "usage: #{$PROGRAM_NAME} <err.html> [max-severity]"
threshold = Integer(ARGV[1] || 1)

abort "#{report}: not found — did the build run?" unless File.exist?(report)

html = File.read(report, encoding: "UTF-8")

# Match table rows only. The stylesheet in the same file also mentions each
# `.severityN` class, which must not be counted as a diagnostic.
severities = html.scan(/<tr\s+class="severity(\d)"/).flatten.map { |s| Integer(s) }

summary = severities.tally.sort.map { |sev, n| "severity #{sev}: #{n}" }.join(", ")
puts(summary.empty? ? "#{report}: no diagnostics" : "#{report}: #{summary}")

offending = severities.count { |sev| sev <= threshold }
abort "#{report}: #{offending} diagnostic(s) at severity <= #{threshold}" if offending.positive?
