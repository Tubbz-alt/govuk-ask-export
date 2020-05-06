require "faraday"
require "json"

module AskExport
  class SurveyResponseFetcher
    RESPONSES_PER_REQUEST = 100

    def self.call(*args, &block)
      new(*args).call(&block)
    end

    def initialize(since_time, until_time)
      @since_time = since_time
      @until_time = until_time
    end

    def call
      page = 1
      responses = []
      loop do
        survey_id = AskExport.config(:survey_id)
        response = http_client.get("surveys/#{survey_id}/responses",
                                   page: page,
                                   page_size: RESPONSES_PER_REQUEST,
                                   since: since_time.to_i,
                                   until: until_time.to_i,
                                   sort_by: "date_ended,asc",
                                   include_labels: true,
                                   completed: 1)

        body = JSON.parse(response.body, symbolize_names: true)

        responses += body.filter { |entry| entry[:status] == "completed" }
                         .map { |entry| ResultPresenter.call(entry) }

        yield responses.count if block_given?

        break if body.length < RESPONSES_PER_REQUEST

        # We're rate limited to 180 requests a minute so we need to slow
        # our requests down a bit
        sleep 0.33
        page += 1
      end

      responses
    end

    private_class_method :new

  private

    attr_reader :since_time, :until_time

    def http_client
      @http_client ||= Faraday.new(
        "https://api.smartsurvey.io/v1/",
        params: {
          api_token: ENV.fetch("SMART_SURVEY_API_TOKEN"),
          api_token_secret: ENV.fetch("SMART_SURVEY_API_TOKEN_SECRET"),
        },
      ) do |f|
        # retry when we got a nil response (likely a timeout), a 429 (rate limit
        # exceeded) and any 500 server errors (covers intermittent ones like bad
        # gateway or gateway timeout)
        retry_if = ->(env, _) { env.status.nil? || env.status == 429 || env.status >= 500 }
        f.request(:retry,
                  max: 3,
                  interval: 20,
                  exceptions: [Faraday::Error],
                  methods: [], # has to be empty for the retry_if to execute
                  retry_if: retry_if)
        f.response(:raise_error)
      end
    end

    class ResultPresenter
      def self.call(*args)
        new(*args).call
      end

      def initialize(result)
        @result = result
      end

      def call
        time_in_local_zone = Time.zone.iso8601(result[:date_ended])
        {
          id: result[:id],
          submission_time: time_in_local_zone.iso8601,
          region: fetch_choice_answer(:region_field_id),
          question: fetch_value_answer(:question_field_id),
          question_format: fetch_choice_answer(:question_format_field_id),
          name: fetch_value_answer(:name_field_id),
          email: fetch_value_answer(:email_field_id),
          phone: fetch_value_answer(:phone_field_id),
        }
      end

      private_class_method :new

    private

      attr_reader :result

      def fetch_value_answer(field_id)
        fetch_answer(field_id).to_h[:value]
      end

      def fetch_choice_answer(field_id)
        fetch_answer(field_id).to_h[:choice_title]
      end

      def fetch_answer(field_id)
        result[:pages].flat_map { |page| page[:questions] }
                      .find { |question| question[:id] == AskExport.config(field_id) }
                      .then { |response| response.to_h[:answers]&.first }
      end
    end
  end
end
