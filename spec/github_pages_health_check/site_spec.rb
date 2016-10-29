# frozen_string_literal: true
require "spec_helper"

RSpec.describe(GitHubPages::HealthCheck::Site) do
  let(:api_base) { "https://api.github.com" }
  let(:repo) { "github/page.github.com" }
  let(:domain) { "pages.github.com" }

  before do
    stub_request(:head, "https://#{domain}/")
      .to_return(:status => 200, :headers => { :server => "GitHub.com" })

    stub_request(:head, "http://#{domain}/")
      .to_return(:status => 200, :headers => { :server => "GitHub.com" })
  end

  %w(domain repo).each do |init_type|
    context "initialized with a #{init_type}" do
      subject do
        return described_class.new(domain) if init_type == "domain"

        subject = nil
        with_env "OCTOKIT_ACCESS_TOKEN", "1234" do
          subject = described_class.new repo
        end
        subject
      end

      context "with a cname" do
        before do
          if init_type == "repo"
            fixture = File.read(fixture_path("pages_info.json"))
            stub_request(:get, "#{api_base}/repos/#{repo}/pages")
              .to_return(:status => 200,
                         :body => fixture,
                         :headers => { "Content-Type" => "application/json" })

            fixture = File.read(fixture_path("build_success.json"))
            stub_request(:get, "#{api_base}/repos/#{repo}/pages/builds/latest")
              .to_return(:status => 200,
                         :body => fixture,
                         :headers => { "Content-Type" => "application/json" })
          end
        end

        it "knows the domain" do
          expect(subject.domain).to be_a(GitHubPages::HealthCheck::Domain)
          expect(subject.domain.host).to eql("pages.github.com")
        end

        it "builds the hash" do
          expect(subject.to_hash[:host]).to eql("pages.github.com")
        end

        if init_type == "repo"
          it "knows the repository" do
            klass = GitHubPages::HealthCheck::Repository
            expect(subject.repository).to be_a(klass)
            expect(subject.repository.name_with_owner).to eql(repo)
          end
        else
          it "knows it doesn't know the repository" do
            expect(subject.repository).to be_nil
          end
        end

        context "json" do
          let(:json) { JSON.parse subject.to_json }

          it "returns valid json" do
            expect(json.delete("uri")).to eql("https://pages.github.com/")
          end
        end

        context "hash" do
          let(:valid_values) { [true, false, nil] }

          it "returns a valid values" do
            hash = subject.to_hash
            expect(hash.delete(:host)).to eql(domain)
            expect(hash.delete(:uri)).to eql("https://#{domain}/")

            if init_type == "repo"
              expect(hash.delete(:name_with_owner)).to eql(repo)
              expect(hash.delete(:last_built).to_s).to match(/2014-02-10/)
              expect(hash.delete(:build_duration)).to eql(2104)
            end

            hash.each do |key, value|
              msg = "Expected #{key} to be one of #{valid_values}"
              expect(valid_values).to include(value), msg
            end
          end
        end
      end

      context "with no cname" do
        before do
          if init_type == "repo"
            fixture = File.read(fixture_path("pages_info_no_cname.json"))
            stub_request(:get, "#{api_base}/repos/#{repo}/pages")
              .to_return(:status => 200,
                         :body => fixture,
                         :headers => { "Content-Type" => "application/json" })

            fixture = File.read(fixture_path("build_success.json"))
            url = "#{api_base}/repos/#{repo}/pages/builds/latest"
            stub_request(:get, url)
              .to_return(:status => 200,
                         :body => fixture,
                         :headers => { "Content-Type" => "application/json" })
          end
        end

        if init_type == "repo"
          it "knows it doesn't know the domain" do
            expect(subject.domain).to be_nil
          end

          it "doesnt err out when it checks" do
            expect(subject.check!).to be_truthy
          end
        end
      end
    end
  end
end
