require "active_support"
require "active_support/time"
Time.zone = "Europe/London"

Dir.glob(File.join(__dir__, "ask_export/**/*.rb")).sort.each { |file| require file }

module AskExport
  CONFIG = {
    draft: {
      survey_id: 741027,
      region_field_id: 11348121,
      question_field_id: 11348119,
      question_format_field_id: 11768689,
      name_field_id: 11348120,
      email_field_id: 11348122,
      phone_field_id: 11348123,
    },
    live: {
      survey_id: 736162,
      region_field_id: 11312915,
      question_field_id: 11288904,
      question_format_field_id: 11768721,
      name_field_id: 11289065,
      email_field_id: 11289069,
      phone_field_id: 11312922,
    },
  }.freeze

  def self.config(item)
    environment = ENV["SMART_SURVEY_LIVE"] == "true" ? :live : :draft
    CONFIG[environment].fetch(item)
  end
end
