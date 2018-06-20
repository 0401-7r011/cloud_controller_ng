require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RotateDatabaseKey do
    describe '#perform' do
      let(:app) { AppModel.make }
      let(:app_new_key_label) { AppModel.make }
      let(:env_vars) { { 'environment' => 'vars' } }
      let(:env_vars_2) { { 'vars' => 'environment' } }

      # Service bindings are an example of multiple encrypted fields
      let(:service_binding) { ServiceBinding.make }
      let(:service_binding_new_key_label) { ServiceBinding.make }
      let(:credentials) { { 'secret' => 'creds' } }
      let(:credentials_2) { { 'more' => 'secrets' } }
      let(:volume_mounts) { { 'volume' => 'mount' } }
      let(:volume_mounts_2) { { 'mount' => 'vesuvius' } }

      # Service instances are an example of single table inheritance
      let(:service_instance) { ManagedServiceInstance.make }
      let(:service_instance_new_key_label) { ManagedServiceInstance.make }
      let(:instance_credentials) { { 'instance' => 'credentials' } }
      let(:instance_credentials_2) { { 'instance_credentials' => 'live here' } }

      let(:database_encryption_keys) { { old: 'old-key', new: 'new-key' } }

      before do
        allow(Encryptor).to receive(:current_encryption_key_label) { 'old' }
        allow(Encryptor).to receive(:database_encryption_keys) { database_encryption_keys }

        app.environment_variables = env_vars
        app.save

        service_binding.credentials = credentials
        service_binding.volume_mounts = volume_mounts
        service_binding.save

        service_instance.credentials = instance_credentials
        service_instance.save

        allow(Encryptor).to receive(:current_encryption_key_label) { 'new' }

        app_new_key_label.environment_variables = env_vars_2
        app_new_key_label.save

        service_binding_new_key_label.credentials = credentials_2
        service_binding_new_key_label.volume_mounts = volume_mounts_2
        service_binding_new_key_label.save

        service_instance_new_key_label.credentials = instance_credentials_2
        service_instance_new_key_label.save

        allow(VCAP::CloudController::Encryptor).to receive(:encrypt).and_call_original
        allow(VCAP::CloudController::Encryptor).to receive(:decrypt).and_call_original
        allow(VCAP::CloudController::Encryptor).to receive(:encrypted_classes).and_return([
          'VCAP::CloudController::ServiceBinding',
          'VCAP::CloudController::AppModel',
          'VCAP::CloudController::ServiceInstance',
        ])
      end

      context 'no current encryption key label is set' do
        before do
          allow(VCAP::CloudController::Encryptor).to receive(:current_encryption_key_label).and_return(nil)
        end

        it 'raises an error' do
          expect {
            RotateDatabaseKey.perform(batch_size: 1)
          }.to raise_error(CloudController::Errors::ApiError, /Please set the desired encryption key/)
        end
      end

      it 'changes the key label of each model' do
        expect(app.encryption_key_label).to eq('old')
        expect(service_binding.encryption_key_label).to eq('old')
        expect(service_instance.encryption_key_label).to eq('old')

        RotateDatabaseKey.perform(batch_size: 1)

        expect(app.reload.encryption_key_label).to eq('new')
        expect(service_binding.reload.encryption_key_label).to eq('new')
        expect(service_instance.reload.encryption_key_label).to eq('new')
      end

      it 're-encrypts all encrypted fields with the new key for all rows' do
        p "========================="

        expect(VCAP::CloudController::Encryptor).to receive(:encrypt).
          with(JSON.dump(env_vars), app.salt).exactly(:twice)

        expect(VCAP::CloudController::Encryptor).to receive(:encrypt).
          with(JSON.dump(credentials), service_binding.salt).exactly(:twice)

        expect(VCAP::CloudController::Encryptor).to receive(:encrypt).
          with(JSON.dump(volume_mounts), service_binding.volume_mounts_salt).exactly(:twice)

        expect(VCAP::CloudController::Encryptor).to receive(:encrypt).
          with(JSON.dump(volume_mounts), service_instance.credentials).exactly(:twice)

        RotateDatabaseKey.perform(batch_size: 1)
      end

      it 'does not change the decrypted value' do
        RotateDatabaseKey.perform(batch_size: 1)

        expect(app.environment_variables).to eq(env_vars)
        expect(service_binding.credentials).to eq(credentials)
        expect(service_binding.volume_mounts).to eq(volume_mounts)
        expect(service_instance.credentials).to eq(instance_credentials)
      end

      it 'does not re-encrypt values that are already encrypted with the new label' do
        expect(VCAP::CloudController::Encryptor).not_to receive(:encrypt).
          with(JSON.dump(env_vars_2), app_new_key_label.salt)

        expect(VCAP::CloudController::Encryptor).not_to receive(:encrypt).
          with(JSON.dump(credentials_2), service_binding_new_key_label.salt)

        expect(VCAP::CloudController::Encryptor).not_to receive(:encrypt).
          with(JSON.dump(volume_mounts_2), service_binding_new_key_label.volume_mounts_salt)

        expect(VCAP::CloudController::Encryptor).not_to receive(:encrypt).
          with(JSON.dump(volume_mounts_2), service_instance.credentials)

        RotateDatabaseKey.perform(batch_size: 1)
      end

      describe 'batching so we do not load entire tables into memory' do
        let(:app2) { AppModel.make }
        let(:app3) { AppModel.make }

        before do
          allow(Encryptor).to receive(:current_encryption_key_label) { 'old' }

          app2.environment_variables = { password: 'hunter2' }
          app2.save

          app3.environment_variables = { feature: 'activate' }
          app3.save

          allow(Encryptor).to receive(:current_encryption_key_label) { 'new' }
        end

        it 'rotates batches until everything is rotated' do
          expect(app.encryption_key_label).to eq('old')
          expect(app2.encryption_key_label).to eq('old')
          expect(app3.encryption_key_label).to eq('old')

          RotateDatabaseKey.perform(batch_size: 1)

          expect(app.reload.encryption_key_label).to eq('new')
          expect(app2.reload.encryption_key_label).to eq('new')
          expect(app3.reload.encryption_key_label).to eq('new')
        end
      end
    end
  end
end
