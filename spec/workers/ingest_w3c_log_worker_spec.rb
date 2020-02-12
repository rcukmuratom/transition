require 'rails_helper'

describe IngestW3cLogWorker, type: :worker do
  let(:s3) { Aws::S3::Client.new(stub_responses: true) }

  before do
    allow(Services).to receive(:s3).and_return(s3)
  end

  describe 'perform' do
    let(:bucket) {"bucket-name"}
    let(:key) {"results.csv"}
    let(:file) {"iis_w3c_example.log"}

    before(:each) do
      s3.stub_responses(:list_objects, contents: [{ key: key, etag: file }])
      s3.stub_responses(:get_object, body: File.open("spec/fixtures/hits/#{file}"))
    end

    it 'fetches files from S3' do
      Sidekiq::Testing.inline! do
        expect(s3).to receive(:list_objects).with(bucket: bucket).and_call_original
        expect(s3).to receive(:get_object).with(bucket: bucket, key: key, response_target: /ingest/).and_call_original
        subject.perform(bucket)
      end
    end

    it 'asks the import service to ingest the file' do
      expect(Transition::Import::Hits).to receive(:from_iis_w3c!)
      subject.perform(bucket)
    end

    it 'uses the ingest queue' do
      described_class.perform_async(bucket)
      expect(Sidekiq::Queues['ingest'].size).to eq(1)
    end

    it 'refreshes the analytics' do
      expect(Transition::Import::DailyHitTotals).to receive(:from_hits!)
      expect(Transition::Import::HitsMappingsRelations).to receive(:refresh!)
      subject.perform(bucket)
    end

    context 'when that file has already been ingested' do
      it 'does not ingest those logs again' do
        ImportedHitsFile.where(filename: file)
        subject.perform(bucket)
        expect(ImportedHitsFile.count).to eq(1)
      end
    end
  end
end
