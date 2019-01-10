require 'spec_helper'
require 'actions/buildpack_upload'
require 'cloud_controller/buildpacks/install_validations/upload_validator'

module VCAP::CloudController
  RSpec.describe BuildpackUpload do
    subject(:buildpack_upload) {BuildpackUpload.new}

    describe '#upload_async' do
      let!(:buildpack) {VCAP::CloudController::Buildpack.create_from_hash({name: 'upload_binary_buildpack', stack: nil, position: 0})}
      let(:message) {BuildpackUploadMessage.new({'bits_path' => '/tmp/path', 'bits_name' => 'buildpack.zip'})}
      let(:config) {Config.new({name: 'local', index: '1'})}

      before do
        allow(Buildpacks::StackNameExtractor).to receive(:extract_from_file).and_return('the-stack')
      end

      context 'when the buildpack and message are valid' do
        before do
          allow(Buildpacks::InstallValidations::UploadValidator).to receive(:validate).and_return(nil)
        end

        it 'enqueues and returns an upload job' do
          returned_job = nil
          expect {
            returned_job = buildpack_upload.upload_async(message: message, buildpack: buildpack, config: config)
          }.to change {Delayed::Job.count}.by(1)

          job = Delayed::Job.last
          expect(returned_job).to eq(job)
          expect(job.queue).to eq('cc-local-1')
          expect(job.handler).to include(buildpack.guid)
          expect(job.handler).to include('BuildpackBits')
        end

        it 'leaves the state as AWAITING_UPLOAD' do
          buildpack_upload.upload_async(message: message, buildpack: buildpack, config: config)
          expect(Buildpack.find(guid: buildpack.guid).state).to eq(Buildpack::CREATED_STATE)
        end

        it 'uses the right path and filename' do
          expect(Jobs::V3::BuildpackBits).to receive(:new).with(
            buildpack.guid,
            '/tmp/path',
            'buildpack.zip'
          )
          buildpack_upload.upload_async(message: message, buildpack: buildpack, config: config)

        end
      end

      context 'when the buildpack and message are invalid' do
        before do
          allow(Buildpacks::InstallValidations::UploadValidator).to receive(:validate).and_raise
        end

        it 'does not enqueue an upload job' do
          job_count = Delayed::Job.count

          expect {
            buildpack_upload.upload_async(message: message, buildpack: buildpack, config: config)
          }.to raise_error

          expect(Delayed::Job.count).to eq(job_count)
        end
      end
    end
  end
end
