# frozen_string_literal: true
require "spec_helper"

describe(GitHubPages::HealthCheck::Repository) do
  subject { described_class.new "github/pages.github.com" }

  context "constructor" do
    context "an invalid repository" do
      it "should raise an error" do
        expected = GitHubPages::HealthCheck::Errors::InvalidRepositoryError
        expect { described_class.new("example.com") }.to raise_error(expected)
      end
    end

    it "should extract the owner" do
      expect(subject.owner).to eql("github")
    end

    it "should extract the repo name" do
      expect(subject.name).to eql("pages.github.com")
    end

    it "should build the name with owner" do
      expect(subject.name_with_owner).to eql("github/pages.github.com")
    end

    it "should parse the access token, when explicitly passed" do
      check = described_class.new("github/pages.github.com", :access_token => "1234")
      expect(check.instance_variable_get("@access_token")).to eql("1234")
    end

    it "should parse the access token when passed as an env var" do
      with_env "OCTOKIT_ACCESS_TOKEN", "1234" do
        check = described_class.new("github/pages.github.com")
        expect(check.instance_variable_get("@access_token")).to eql("1234")
      end
    end
  end

  %w(error success).each do |type|
    context "a build that was a(n) #{type}" do
      before do
        subject.instance_variable_set("@access_token", "1234")
        fixture = File.read(fixture_path("build_#{type}.json"))
        stub_request(:get, "https://api.github.com/repos/github/pages.github.com/pages/builds/latest")
          .to_return(:status => 200, :body => fixture, :headers => { "Content-Type" => "application/json" })
      end

      if type == "error"
        it "fails the check" do
          expect { subject.check! }.to raise_error(GitHubPages::HealthCheck::Errors::BuildError)
        end

        it "returns the build error" do
          expect(subject.build_error).to eql("Some message")
        end

        it "knows the site wasn't built" do
          expect(subject.built?).to eql(false)
        end
      else
        it "passes the check" do
          expect(subject.check!).to eql(true)
        end

        it "returns no build error" do
          expect(subject.build_error).to eql(nil)
        end

        it "knows the site was built" do
          expect(subject.built?).to eql(true)
        end
      end

      it "returns the build info" do
        expected = "351391cdcb88ffae71ec3028c91f375a8036a26b"
        expect(subject.last_build["commit"]).to eql(expected)
      end

      it "knows the build duration" do
        expect(subject.build_duration).to eql(2104)
      end

      it "knows when it was last built" do
        expect(subject.last_built.to_s).to match(/2014-02-10/)
      end
    end
  end

  context "the client" do
    context "with an access token" do
      before { subject.instance_variable_set("@access_token", "1234") }

      it "inits the client" do
        expect(subject.send(:client).class).to eql(Octokit::Client)
      end

      it "passes the token" do
        expect(subject.send(:client).access_token).to eql("1234")
      end
    end

    context "without an access token" do
      before { subject.instance_variable_set("@access_token", nil) }

      it "raises an error" do
        expected = GitHubPages::HealthCheck::Errors::MissingAccessTokenError
        expect { subject.send(:client) }.to raise_error(expected)
      end
    end
  end

  context "pages info" do
    before do
      subject.instance_variable_set("@access_token", "1234")
      fixture = File.read(fixture_path("pages_info.json"))
      stub_request(:get, "https://api.github.com/repos/github/pages.github.com/pages")
        .to_return(:status => 200, :body => fixture, :headers => { "Content-Type" => "application/json" })
    end

    it "returns the pages info" do
      expect(subject.send(:pages_info).status).to eql("built")
    end

    it "knows the CNAME" do
      expect(subject.send(:cname)).to eql("pages.github.com")
    end

    it "returns the domain" do
      expect(subject.domain.class).to eql(GitHubPages::HealthCheck::Domain)
      expect(subject.domain.host).to eql("pages.github.com")
    end

    context "without a CNAME" do
      before do
        subject.instance_variable_set("@access_token", "1234")
        fixture = File.read(fixture_path("pages_info_no_cname.json"))
        stub_request(:get, "https://api.github.com/repos/github/pages.github.com/pages")
          .to_return(:status => 200, :body => fixture, :headers => { "Content-Type" => "application/json" })
      end

      it "doesn't try to build the domain" do
        expect(subject.domain).to be_nil
      end
    end
  end
end
