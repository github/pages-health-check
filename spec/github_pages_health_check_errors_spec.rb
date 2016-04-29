require "spec_helper"

describe(GitHubPages::HealthCheck::Errors) do
  it "returns the errors" do
    expect(GitHubPages::HealthCheck::Errors.all.count).to eql(9)
  end

  # Errors used locally that do not have coresponding documentation URLs
  ERROR_WHITELIST = [
    GitHubPages::HealthCheck::Errors::MissingAccessTokenError,
    GitHubPages::HealthCheck::Errors::InvalidRepositoryError
  ]

  GitHubPages::HealthCheck::Errors.all.each do |klass|
    next if ERROR_WHITELIST.include?(klass)
    
    context "The #{klass.name.split('::').last} error" do
      let(:domain) { GitHubPages::HealthCheck::Domain.new("example.com") }
      subject { klass.new(domain: domain) }

      it "has a message" do
        expect(subject.message).to_not be_empty
      end

      it "has a documentation url" do
        expect(klass::DOCUMENTATION_PATH).to_not be_nil
        expect(klass::DOCUMENTATION_PATH).to_not be_empty
        expect(subject.send(:documentation_url)).to_not be_nil
      end
    end
  end
end
