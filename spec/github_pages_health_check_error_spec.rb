require "spec_helper"

describe(GitHubPages::HealthCheck::Error) do

  GitHubPages::HealthCheck::Errors.all.each do |klass|
    next if klass::LOCAL_ONLY
    
    context "The #{klass.name.split('::').last} error" do
      let(:domain) { GitHubPages::HealthCheck::Domain.new("example.com") }
      subject { klass.new(domain: domain) }

      it "has a message" do
        expect(subject.message).to_not be_empty
      end

      it "has a documentation url" do
        expect(klass::DOCUMENTATION_PATH).to_not be_nil
        expect(klass::DOCUMENTATION_PATH).to_not be_empty
        default = "/categories/github-pages-basics/"
        expect(klass::DOCUMENTATION_PATH).to_not eql(default)
        expect(subject.send(:documentation_url)).to_not be_nil
      end
    end
  end

  context "with a repository" do
    let(:nwo) { "github/pages.github.com" }
    let(:repo) { GitHubPages::HealthCheck::Repository.new(nwo) }
    subject { described_class.new(repository: repo) }

    it "knows the username" do
      expect(subject.send(:username)).to eql("github")
    end
  end

  context "without a repository" do
    it "has a placeholder username" do
      expect(subject.send(:username)).to eql("[YOUR USERNAME]")
    end
  end

  it "builds the documentation URL" do
    url = "https://help.github.com/categories/github-pages-basics/"
    expect(subject.send(:documentation_url)).to eql(url)
  end

  it "builds the more info string" do
    msg = "For more information, "
    msg << "see https://help.github.com/categories/github-pages-basics/."
    expect(subject.send(:more_info)).to eql(msg)
  end

  it "returns the message with URL" do
    msg = "Something's wrong with your GitHub Pages site. "
    msg << "For more information, "
    msg << "see https://help.github.com/categories/github-pages-basics/."
    expect(subject.message_with_url).to eql(msg)
  end
end
