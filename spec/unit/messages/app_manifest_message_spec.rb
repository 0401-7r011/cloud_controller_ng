require 'spec_helper'
require 'messages/app_manifest_message'

module VCAP::CloudController
  RSpec.describe AppManifestMessage do
    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { instances: 3, memory: '2G', name: 'foo' } }

        it 'is valid' do
          message = AppManifestMessage.new(params)

          expect(message).to be_valid
        end
      end

      describe 'memory' do
        context 'when memory unit is not part of expected set of values' do
          let(:params) { { memory: '200INVALID' } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Memory must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB')
          end
        end

        context 'when memory is not a positive amount' do
          let(:params) { { memory: '-1MB' } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Memory must be greater than 0MB')
          end
        end

        context 'when memory is in bytes' do
          let(:params) { { memory: '-35B' } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Memory must be greater than 0MB')
          end
        end
      end

      describe 'disk_quota' do
        context 'when disk_quota unit is not part of expected set of values' do
          let(:params) { { disk_quota: '200INVALID' } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Disk quota must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB')
          end
        end

        context 'when disk_quota is not a positive amount' do
          let(:params) { { disk_quota: '-1MB' } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Disk quota must be greater than 0MB')
          end
        end

        context 'when disk_quota is not numeric' do
          let(:params) { { disk_quota: 'gerg herscheiser' } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Disk quota is not a number')
          end
        end
      end

      describe 'buildpack' do
        context 'when the buildpack is not a string' do
          let(:params) { { buildpack: 99 } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Lifecycle Buildpacks can only contain strings')
          end
        end

        context 'when the buildpack is not a known name or url' do
          let(:params) { { buildpack: 'i am not a buildpack' } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include(%/Buildpack "#{params[:buildpack]}" must be an existing admin buildpack or a valid git URI/)
          end
        end
      end

      describe 'stack' do
        context 'when providing a valid stack name' do
          let(:params) { {stack: 'cflinuxfs2'} }

          it 'is valid' do
            message = AppManifestMessage.new(params)

            expect(message).to be_valid
            expect(message.stack).to eq('cflinuxfs2')
          end
        end

        context 'when the stack is not a string' do
          let(:params) { { stack: 99 } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Stack must be a string')
          end
        end

        context 'when the stack is not a known stack' do
          let(:params) { { stack: 'garbage' } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include(%/Stack "#{params[:stack]}" must be an existing stack/)
          end
        end
      end

      describe 'instances' do
        context 'when instances is not an number' do
          let(:params) { { instances: 'silly string thing' } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Instances is not a number')
          end
        end

        context 'when instances is not an integer' do
          let(:params) { { instances: 3.5 } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Instances must be an integer')
          end
        end

        context 'when instances is not a positive integer' do
          let(:params) { { instances: -1 } }

          it 'is not valid' do
            message = AppManifestMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Instances must be greater than or equal to 0')
          end
        end
      end

      context 'when there are multiple errors' do
        let(:params) { { instances: -1, memory: 120 } }

        it 'is not valid' do
          message = AppManifestMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(2)
          expect(message.errors.full_messages).to match_array([
            'Instances must be greater than or equal to 0',
            'Memory must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB'
          ])
        end
      end
    end

    describe '.create_from_http_request' do
      let(:parsed_yaml) { { 'name' => 'blah', 'instances' => 4, 'memory' => '200GB' } }

      it 'returns the correct AppManifestMessage' do
        message = AppManifestMessage.create_from_http_request(parsed_yaml)

        expect(message).to be_valid
        expect(message).to be_a(AppManifestMessage)
        expect(message.instances).to eq(4)
        expect(message.memory).to eq('200GB')
      end

      it 'converts requested keys to symbols' do
        message = AppManifestMessage.create_from_http_request(parsed_yaml)

        expect(message.requested?(:instances)).to be_truthy
        expect(message.requested?(:memory)).to be_truthy
      end
    end

    describe '#process_scale_message' do
      let(:parsed_yaml) { { 'disk_quota' => '1000GB', 'memory' => '200GB', instances: 5 } }

      it 'returns a ManifestProcessScaleMessage containing mapped attributes' do
        message = AppManifestMessage.create_from_http_request(parsed_yaml)

        expect(message.manifest_process_scale_message.instances).to eq(5)
        expect(message.manifest_process_scale_message.memory).to eq(204800)
        expect(message.manifest_process_scale_message.disk_quota).to eq(1024000)
      end

      context 'it handles bytes' do
        let(:parsed_yaml) { { 'disk_quota' => '7340032B', 'memory' => '3145728B', instances: 8 } }

        it 'returns a ManifestProcessScaleMessage containing mapped attributes' do
          message = AppManifestMessage.create_from_http_request(parsed_yaml)
          expect(message).to be_valid
          expect(message.manifest_process_scale_message.instances).to eq(8)
          expect(message.manifest_process_scale_message.memory).to eq(3)
          expect(message.manifest_process_scale_message.disk_quota).to eq(7)
        end
      end

      context 'it handles exactly 1MB' do
        let(:parsed_yaml) { { 'disk_quota' => '1048576B', 'memory' => '1048576B', instances: 8 } }

        it 'returns a ManifestProcessScaleMessage containing mapped attributes' do
          message = AppManifestMessage.create_from_http_request(parsed_yaml)
          expect(message).to be_valid
          expect(message.manifest_process_scale_message.instances).to eq(8)
          expect(message.manifest_process_scale_message.memory).to eq(1)
          expect(message.manifest_process_scale_message.disk_quota).to eq(1)
        end
      end

      context 'it complains about 1MB - 1' do
        let(:parsed_yaml) { { 'disk_quota' => '1048575B', 'memory' => '1048575B', instances: 8 } }

        it 'returns a ManifestProcessScaleMessage containing mapped attributes' do
          message = AppManifestMessage.create_from_http_request(parsed_yaml)
          expect(message).not_to be_valid
          expect(message.errors.count).to eq(2)
          expect(message.errors.full_messages).to match_array(['Memory must be greater than 0MB', 'Disk quota must be greater than 0MB'])
        end
      end

      context 'when attributes are not requested in the manifest' do
        let(:parsed_yaml) { {} }

        it 'does not forward missing attributes to the ManifestProcessScaleMessage' do
          message = AppManifestMessage.create_from_http_request(parsed_yaml)

          expect(message.process_scale_message.requested?(:instances)).to be false
          expect(message.process_scale_message.requested?(:memory)).to be false
          expect(message.process_scale_message.requested?(:disk_quota)).to be false
        end
      end
    end

    describe '#app_update_message' do
      let(:buildpack) { VCAP::CloudController::Buildpack.make }
      let(:parsed_yaml) { { 'buildpack' => buildpack.name } }

      it 'returns an AppUpdateMessage containing mapped attributes' do
        message = AppManifestMessage.create_from_http_request(parsed_yaml)

        expect(message.app_update_message.buildpack_data.buildpacks).to include(buildpack.name)
      end

      context 'when attributes are not requested in the manifest' do
        let(:parsed_yaml) { {} }

        it 'does not forward missing attributes to the AppUpdateMessage' do
          message = AppManifestMessage.create_from_http_request(parsed_yaml)

          expect(message.app_update_message.requested?(:lifecycle)).to be false
        end
      end

      context 'when it specifies a "default" buildpack' do
        let(:parsed_yaml) { { buildpack: 'default' } }
        it 'updates the buildpack_data to be an empty array' do
          message = AppManifestMessage.create_from_http_request(parsed_yaml)
          expect(message.app_update_message.buildpack_data.buildpacks).to be_empty
        end
      end

      context 'when it specifies a null buildpack' do
        let(:parsed_yaml) { { buildpack: nil } }
        it 'updates the buildpack_data to be an empty array' do
          message = AppManifestMessage.create_from_http_request(parsed_yaml)
          expect(message.app_update_message.buildpack_data.buildpacks).to be_empty
        end
      end
    end
  end
end
