class IngestFromCombinedLogFormat
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: 'ingest'

  def perform(bucket)
    puts "Ingesting CLF logs from: #{bucket}"

    Services.s3.list_objects(bucket: bucket).each do |resp|
      resp.contents.each do |object|
        puts "Importing #{object.key}"
        next unless object.key.end_with? '.clf'

        file_path = "data/#{object.key}"
        Services.s3.get_object(bucket: bucket, key: object.key, response_target: file_path)

        Transition::Import::Hits.from_clf!(file_path)

        Transition::Import::DailyHitTotals.from_hits!
        Transition::Import::HitsMappingsRelations.refresh!

        File.delete(file_path)
      end
    end

    puts "Finished ingest."
  end
end
