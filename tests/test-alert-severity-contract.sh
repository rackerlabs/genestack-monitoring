#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

command -v ruby >/dev/null 2>&1 || {
    echo "[FAIL] ruby is required" >&2
    exit 1
}

ruby - "${PROJECT_ROOT}" <<'RUBY'
require "yaml"

root = ARGV.fetch(0)
failures = []
severity_counts = Hash.new(0)

def alert_rules_from(document)
  maps = []
  if document.is_a?(Hash) && document["additionalPrometheusRulesMap"].is_a?(Hash)
    maps.concat(document["additionalPrometheusRulesMap"].values)
  elsif document.is_a?(Hash) && document["groups"].is_a?(Array)
    maps << document
  end

  maps.flat_map do |item|
    groups = item.is_a?(Hash) ? item["groups"] : []
    Array(groups).flat_map do |group|
      rules = group.is_a?(Hash) ? group["rules"] : []
      Array(rules).select { |rule| rule.is_a?(Hash) && rule["alert"].to_s.strip != "" }
    end
  end
end

Dir.glob(File.join(root, "alerts", "**", "*.y{a,}ml")).sort.each do |path|
  relative_path = path.delete_prefix("#{root}/")
  document = YAML.load_file(path)
  alerts = alert_rules_from(document)
  alerts.each do |rule|
    name = rule["alert"].to_s.strip
    labels = rule["labels"].is_a?(Hash) ? rule["labels"] : {}
    severity = labels["severity"].to_s.strip.downcase
    severity_counts[severity.empty? ? "<missing>" : severity] += 1

    if severity.empty?
      failures << "#{relative_path}:#{name} missing labels.severity"
      next
    end

    if ["warning", "critical"].include?(severity)
      expected_suffix = "-#{severity}"
      unless name.end_with?(expected_suffix)
        failures << "#{relative_path}:#{name} severity=#{severity} must end with #{expected_suffix}"
      end
    end
  end
end

if failures.any?
  warn "[FAIL] Genestack alert severity contract failed"
  failures.each { |failure| warn "  - #{failure}" }
  exit 1
end

puts "[PASS] Genestack alert severity contract checks passed #{severity_counts.sort.to_h}"
RUBY
