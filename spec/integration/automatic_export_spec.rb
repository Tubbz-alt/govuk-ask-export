RSpec.describe "Automatic export" do
  around do |example|
    ClimateControl.modify(
      SMART_SURVEY_API_TOKEN: "token",
      SMART_SURVEY_API_TOKEN_SECRET: "token",
      AWS_ACCESS_KEY_ID: "12345",
      AWS_SECRET_ACCESS_KEY: "secret",
      AWS_REGION: "eu-west-1",
      S3_BUCKET: "bucket",
    ) { example.run }
  end

  around do |example|
    travel_to(Time.zone.parse("2020-05-01 10:00")) { example.run }
  end

  around do |example|
    expect { example.run }.to output.to_stdout
  end

  let!(:smart_survey_request) { stub_smart_survey_api }
  let!(:s3_request) do
    stub_request(:put, /bucket\.s3\.eu-west-1\.amazonaws\.com/)
  end

  it "fetches surveys and uploads them to s3" do
    Rake::Task["export"].invoke
    expect(smart_survey_request).to have_been_made
    expect(s3_request).to have_been_made.twice
  end
end
