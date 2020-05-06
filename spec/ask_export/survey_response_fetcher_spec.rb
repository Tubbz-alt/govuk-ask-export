RSpec.describe AskExport::SurveyResponseFetcher do
  describe ".call" do
    before do
      allow_any_instance_of(described_class).to receive(:sleep)
      allow_any_instance_of(Faraday::Request::Retry).to receive(:sleep)
    end

    around do |example|
      ClimateControl.modify(
        SMART_SURVEY_API_TOKEN: "token",
        SMART_SURVEY_API_TOKEN_SECRET: "secret",
      ) { example.run }
    end

    let(:since_time) { Date.yesterday.noon }
    let(:until_time) { Date.current.noon }

    it "requests responses in smart survey covering the dates specified" do
      request = stub_smart_survey_api(since_time: since_time,
                                      until_time: until_time)
      described_class.call(since_time, until_time)
      expect(request).to have_been_made
    end

    it "returns a hash of a presented response from Smart Survey" do
      presented_response = presented_survey_response
      stub_smart_survey_api(body: [smart_survey_row(presented_response)])
      expect(described_class.call(since_time, until_time))
        .to eql([presented_response])
    end

    it "strips responses from Smart Survey which don't have a status of completed" do
      stub_smart_survey_api(body: [smart_survey_row(status: "disqualified")])
      expect(described_class.call(since_time, until_time)).to eql([])
    end

    it "retries 429 responses 3 times before raising an error" do
      request = stub_smart_survey_api(status: 429)
      expect { described_class.call(since_time, until_time) }
        .to raise_error(Faraday::ClientError)
      expect(request).to have_been_made.times(4)
    end

    it "retries timeout responses 3 times before raising an error" do
      request = stub_request(:get, /api\.smartsurvey\.io/).to_timeout
      expect { described_class.call(since_time, until_time) }
        .to raise_error(Faraday::ConnectionFailed)
      expect(request).to have_been_made.times(4)
    end

    it "doesn't retry other 4xx responses" do
      request = stub_smart_survey_api(status: 404)
      expect { described_class.call(since_time, until_time) }
        .to raise_error(Faraday::ClientError)
      expect(request).to have_been_made.once
    end

    it "requests multiple pages when there are more results than the page size" do
      page1_request = stub_smart_survey_api(body: smart_survey_response(100),
                                            page: 1)
      page2_request = stub_smart_survey_api(body: smart_survey_response(50),
                                            page: 2)

      results = described_class.call(since_time, until_time)

      expect(results.count).to eql(150)
      expect(page1_request).to have_been_made
      expect(page2_request).to have_been_made
    end

    it "sleeps between each request" do
      stub_smart_survey_api(body: smart_survey_response(100), page: 1)
      stub_smart_survey_api(body: smart_survey_response(100), page: 2)
      stub_smart_survey_api(body: smart_survey_response(50), page: 3)

      expect_any_instance_of(described_class).to receive(:sleep).twice
      described_class.call(since_time, until_time)
    end

    it "yields a block with the current count of total results" do
      stub_smart_survey_api(body: smart_survey_response(100), page: 1)
      stub_smart_survey_api(body: smart_survey_response(100), page: 2)
      stub_smart_survey_api(body: smart_survey_response(50), page: 3)
      expect { |block| described_class.call(since_time, until_time, &block) }
        .to yield_successive_args(100, 200, 250)
    end

    it "defaults to the draft environment" do
      draft_request = stub_smart_survey_api(environment: :draft)
      described_class.call(since_time, until_time)
      expect(draft_request).to have_been_made
    end

    it "can use the live environment" do
      live_request = stub_smart_survey_api(environment: :live)
      ClimateControl.modify(SMART_SURVEY_LIVE: "true") do
        described_class.call(since_time, until_time)
      end
      expect(live_request).to have_been_made
    end
  end
end
