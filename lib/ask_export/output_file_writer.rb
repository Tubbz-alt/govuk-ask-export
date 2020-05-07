module AskExport
  class OutputFileWriter
    def self.call(*args)
      new(*args).call
    end

    def initialize(daily_report)
      @daily_report = daily_report
    end

    def call
      File.write(cabinet_office_path, csv_builder.cabinet_office, mode: "w")
      File.write(third_party_path, csv_builder.third_party, mode: "w")

      puts "CSV files have been output to #{relative_to_cwd(cabinet_office_path)} " \
        "and #{relative_to_cwd(third_party_path)}"
    end

  private

    attr_reader :daily_report

    def csv_builder
      @csv_builder ||= CsvBuilder.new(daily_report.responses)
    end

    def cabinet_office_path
      "#{output_directory}/#{daily_report.until_time.to_date}-cabinet-office.csv"
    end

    def third_party_path
      "#{output_directory}/#{daily_report.until_time.to_date}-third-party.csv"
    end

    def output_directory
      ENV.fetch(
        "OUTPUT_DIR",
        File.expand_path("../../output", __dir__),
      )
    end

    def relative_to_cwd(path)
      Pathname.new(path).relative_path_from(Pathname.new(Dir.pwd))
    end
  end
end
