require 'rails_helper'
require 'models/helpers/process_types'

RSpec.describe AppManifestsController, type: :controller do
  describe '#apply_manifest' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }
    let(:app_apply_manifest_action) { instance_double(VCAP::CloudController::AppApplyManifest) }
    let(:request_body) { { 'applications' => [{ 'name' => 'blah', 'instances' => 2 }] } }

    before do
      set_current_user_as_role(role: 'admin', org: org, space: space, user: user)
      allow(VCAP::CloudController::Jobs::ApplyManifestActionJob).to receive(:new).and_call_original
      allow(VCAP::CloudController::AppApplyManifest).to receive(:new).and_return(app_apply_manifest_action)
      request.headers['CONTENT_TYPE'] = 'application/x-yaml'
      VCAP::CloudController::ProcessModel.make(app: app_model, type: VCAP::CloudController::ProcessTypes::WEB)
    end

    context 'permissions' do
      describe 'authorization' do
        role_to_expected_http_response = {
          'admin' => 202,
          'admin_read_only' => 403,
          'global_auditor' => 403,
          'space_developer' => 202,
          'space_manager' => 403,
          'space_auditor' => 403,
          'org_manager' => 403,
          'org_auditor' => 404,
          'org_billing_manager' => 404,
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(role: role, org: org, space: space, user: user)

              post :apply_manifest, guid: app_model.guid, body: request_body

              expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
            end
          end
        end
      end
    end

    context 'when the request body is invalid' do
      context 'when the yaml is missing an applications array' do
        let(:request_body) { { 'name' => 'blah', 'instances' => 4 } }

        it 'returns a 400' do
          post :apply_manifest, guid: app_model.guid, body: request_body
          expect(response.status).to eq(400)
        end
      end

      context 'when the requested applications array is empty' do
        let(:request_body) { { 'applications' => [] } }

        it 'returns a 400' do
          post :apply_manifest, guid: app_model.guid, body: request_body
          expect(response.status).to eq(400)
        end

        context 'when the app does not exist' do
          let(:request_body) { { 'applications' => [{ 'name' => 'blah', 'instances' => 1, 'memory' => '4MB' }] } }

          it 'returns a 400' do
            post :apply_manifest, guid: 'no-such-app-guid', body: request_body
            expect(response.status).to eq(404)
          end
        end
      end

      context 'when specified manifest fails validations' do
        let(:request_body) do
          { 'applications' => [{ 'name' => 'blah', 'instances' => -1, 'memory' => '10NOTaUnit' }] }
        end

        it 'returns a 422 and validation errors' do
          post :apply_manifest, guid: app_model.guid, body: request_body
          expect(response.status).to eq(422)
          errors = parsed_body['errors']
          expect(errors.size).to eq(2)

          expect(errors[0]).to include({
            'detail' => 'Memory must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB',
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008
          })

          expect(errors[1]).to include({
            'detail' => 'Instances must be greater than or equal to 0',
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008
          })
        end
      end

      context 'when the request payload is not yaml' do
        let(:request_body) { { 'applications' => [{ 'name' => 'blah', 'instances' => 1 }] } }
        before do
          allow(CloudController::Errors::ApiError).to receive(:new_from_details).and_call_original
          request.headers['CONTENT_TYPE'] = 'text/plain'
        end

        it 'returns a 400' do
          post :apply_manifest, guid: app_model.guid, body: request_body
          expect(response.status).to eq(400)
          # Verify we're getting the InvalidError we're expecting
          expect(CloudController::Errors::ApiError).to have_received(:new_from_details).with('InvalidRequest', 'Content-Type must be yaml').exactly :once
        end
      end
    end

    context 'when the request body includes a buildpack' do
      let!(:php_buildpack) { VCAP::CloudController::Buildpack.make(name: 'php_buildpack') }
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'instances' => 4, 'buildpack' => 'php_buildpack' }] }
      end

      it 'sets the buildpack' do
        post :apply_manifest, guid: app_model.guid, body: request_body

        expect(response.status).to eq(202)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message , action|
          expect(app_guid).to eq app_model.guid
          expect(message.buildpack).to eq 'php_buildpack'
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    context 'when the request body includes a stack' do
      let(:request_body) do
        { 'applications' =>
          [{ 'name' => 'blah', 'stack' => 'cflinuxfs2' }] }
      end

      it 'sets the stack' do
        post :apply_manifest, guid: app_model.guid, body: request_body

        expect(response.status).to eq(202)
        app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
        expect(app_apply_manifest_jobs.count).to eq 1

        expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message , action|
          expect(app_guid).to eq app_model.guid
          expect(message.stack).to eq 'cflinuxfs2'
          expect(action).to eq app_apply_manifest_action
        end
      end
    end

    it 'successfully scales the app in a background job' do
      post :apply_manifest, guid: app_model.guid, body: request_body

      expect(response.status).to eq(202)
      app_apply_manifest_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppApplyManifest%'"))
      expect(app_apply_manifest_jobs.count).to eq 1

      expect(VCAP::CloudController::Jobs::ApplyManifestActionJob).to have_received(:new) do |app_guid, message , action|
        expect(app_guid).to eq app_model.guid
        expect(message.instances).to eq '2'
        expect(action).to eq app_apply_manifest_action
      end
    end

    it 'creates a job to track the applying the app manifest and returns it in the location header' do
      set_current_user_as_role(role: 'admin', org: org, space: space, user: user)

      expect {
        post :apply_manifest, guid: app_model.guid, body: request_body
      }.to change {
        VCAP::CloudController::PollableJobModel.count
      }.by(1)

      job          = VCAP::CloudController::PollableJobModel.last
      enqueued_job = Delayed::Job.last
      expect(job.delayed_job_guid).to eq(enqueued_job.guid)
      expect(job.operation).to eq('app.apply_manifest')
      expect(job.state).to eq('PROCESSING')
      expect(job.resource_guid).to eq(app_model.guid)
      expect(job.resource_type).to eq('app')

      expect(response.status).to eq(202)
      expect(response.headers['Location']).to include "#{link_prefix}/v3/jobs/#{job.guid}"
    end
  end
end
