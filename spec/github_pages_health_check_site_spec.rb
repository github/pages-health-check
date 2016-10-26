require "spec_helper"

describe(GitHubPages::HealthCheck::Site) do
  before do
    stub_request(:head, "https://pages.github.com/").
       to_return(:status => 200, :headers => {:server => "GitHub.com"})

    stub_request(:head, "http://pages.github.com/").
      to_return(:status => 200, :headers => {:server => "GitHub.com"})
  end

  ["domain", "repo"].each do |init_type|
    context "initialized with a #{init_type}" do
      subject do
        return described_class.new("pages.github.com") if init_type == "domain"

        subject = nil
        with_env "OCTOKIT_ACCESS_TOKEN", "1234" do
          subject = described_class.new "github/pages.github.com"
        end
        subject
      end

      before do
        if init_type == "repo"
          fixture = File.read(fixture_path("pages_info.json"))
          stub_request(:get, "https://api.github.com/repos/github/pages.github.com/pages").
            to_return(:status => 200, :body => fixture, :headers => {'Content-Type'=>'application/json'})

          fixture = File.read(fixture_path("build_success.json"))
          stub_request(:get, "https://api.github.com/repos/github/pages.github.com/pages/builds/latest").
              to_return(:status => 200, :body => fixture, :headers => {'Content-Type'=>'application/json'})
        end
      end

      it "knows the domain" do
        expect(subject.domain.class).to eql(GitHubPages::HealthCheck::Domain)
        expect(subject.domain.host).to eql("pages.github.com")
      end

      it "builds the hash" do
        expect(subject.to_hash[:host]).to eql("pages.github.com")
      end

      if init_type == "repo"
        it "knows the repository" do
          expect(subject.repository.class).to eql(GitHubPages::HealthCheck::Repository)
          expect(subject.repository.name_with_owner).to eql("github/pages.github.com")
        end
      else
        it "knows it doesn't know the repository" do
          expect(subject.repository).to eql(nil)
        end
      end

      context "with no cname" do
        before do
          if init_type == "repo"
            fixture = File.read(fixture_path("pages_info_no_cname.json"))
            stub_request(:get, "https://api.github.com/repos/github/pages.github.com/pages").
              to_return(:status => 200, :body => fixture, :headers => {'Content-Type'=>'application/json'})

            fixture = File.read(fixture_path("build_success.json"))
            stub_request(:get, "https://api.github.com/repos/github/pages.github.com/pages/builds/latest").
                to_return(:status => 200, :body => fixture, :headers => {'Content-Type'=>'application/json'})
          end
        end

        if init_type == "repo"
          it "knows it doesn't know the domain" do
            expect(subject.domain).to eql(nil)
          end

          it "doesnt err out when it checks" do
            expect(subject.check!).to eql(true)
          end
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
          expect(hash.delete(:host)).to eql("pages.github.com")
          expect(hash.delete(:uri)).to eql("https://pages.github.com/")

          if init_type == "repo"
            expect(hash.delete(:name_with_owner)).to eql("github/pages.github.com")
            expect(hash.delete(:last_built).to_s).to match(/2014-02-10/)
            expect(hash.delete(:build_duration)).to eql(2104)
          end

          hash.each do |key,value|
            expect(valid_values).to include(value), "Expected #{key} to be one of #{valid_values}"
          end
        end
      end
    end
  end
end
