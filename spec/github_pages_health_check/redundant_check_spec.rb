require "spec_helper"

RSpec.describe(GitHubPages::HealthCheck::RedundantCheck) do
  let(:domain) { "www.parkermoore.de" }
  subject { described_class.new(domain) }
  before(:each) do
    stub_request(:head, "http://#{domain}/")
      .to_return(:status => 200, :body => "", :headers => { "Server" => "GitHub.com" })
  end

  it { is_expected.to be_valid }
  it { is_expected.to be_https_eligible }

  it "has a link to the check which was most valid" do
    expect(subject.check).not_to be_nil
    expect(subject.check).to be_valid
  end
end
