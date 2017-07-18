# frozen_string_literal: true
require "spec_helper"

class CheckableHelper < GitHubPages::HealthCheck::Checkable
  def check!
    if ENV["OCTOKIT_ACCESS_TOKEN"].to_s.empty?
      raise GitHubPages::HealthCheck::Errors::MissingAccessTokenError
    end

    true
  end
end

RSpec.describe(CheckableHelper) do
  context "valid" do
    it "knows the check is valid" do
      with_env "OCTOKIT_ACCESS_TOKEN", "1234" do
        expect(subject.valid?).to eql(true)
      end
    end
  end

  context "invalid" do
    it "knows the check is invalid" do
      with_env "OCTOKIT_ACCESS_TOKEN", "" do
        expect(subject.valid?).to eql(false)
      end
    end

    it "knows the reason" do
      with_env "OCTOKIT_ACCESS_TOKEN", "" do
        expected = GitHubPages::HealthCheck::Errors::MissingAccessTokenError
        expect(subject.reason.class).to eql(expected)
      end
    end
  end
end
