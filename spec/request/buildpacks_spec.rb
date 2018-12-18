require 'spec_helper'

RSpec.describe 'buildpacks' do
  describe 'POST /v3/buildpacks' do
    context 'when not authenticated' do
      it 'returns 401' do
        params = {}
        headers = {}

        post '/v3/buildpacks', params, headers

        expect(last_response.status).to eq(401)
      end
    end

    context 'when authenticated but not admin' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { headers_for(user) }

      it 'returns 403' do
        params = {}

        post '/v3/buildpacks', params, headers

        expect(last_response.status).to eq(403)
      end
    end

    context 'when authenticated and admin' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { admin_headers_for(user) }

      context 'when successful' do
        let(:stack) { VCAP::CloudController::Stack.make }
        let(:params) do
          {
            name: 'the-r3al_Name',
            stack: stack.name,
            enabled: false,
            locked: true,
          }
        end

        it 'returns 201' do
          post '/v3/buildpacks', params.to_json, headers

          expect(last_response.status).to eq(201)
        end

        describe 'non-position values' do
          it 'returns the newly-created buildpack resource' do
            post '/v3/buildpacks', params.to_json, headers

            buildpack = VCAP::CloudController::Buildpack.last

            expected_response = {
              'name' => params[:name],
              'position' => 1,
              'state' => 'AWAITING_UPLOAD',
              'stack' => params[:stack],
              'enabled' => params[:enabled],
              'locked' => params[:locked],
              'guid' => buildpack.guid,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/buildpacks/#{buildpack.guid}"
                }
              }
            }
            expect(parsed_response).to be_a_response_like(expected_response)
          end
        end

        describe 'position' do
          let!(:buildpack1) { VCAP::CloudController::Buildpack.make(position: 1) }
          let!(:buildpack2) { VCAP::CloudController::Buildpack.make(position: 2) }
          let!(:buildpack3) { VCAP::CloudController::Buildpack.make(position: 3) }

          context 'the position is not provided' do
            it 'defaults the position value to 1' do
              post '/v3/buildpacks', params.to_json, headers

              expect(parsed_response['position']).to eq(1)
              expect(buildpack1.reload.position).to eq(2)
              expect(buildpack2.reload.position).to eq(3)
              expect(buildpack3.reload.position).to eq(4)
            end
          end

          context 'the position is less than or equal to the total number of buildpacks' do
            before do
              params[:position] = 2
            end

            it 'sets the position value to the provided position' do
              post '/v3/buildpacks', params.to_json, headers

              expect(parsed_response['position']).to eq(2)
              expect(buildpack1.reload.position).to eq(1)
              expect(buildpack2.reload.position).to eq(3)
              expect(buildpack3.reload.position).to eq(4)
            end
          end

          context 'the position is greater than the total number of buildpacks' do
            before do
              params[:position] = 42
            end

            it 'sets the position value to the provided position' do
              post '/v3/buildpacks', params.to_json, headers

              expect(parsed_response['position']).to eq(4)
              expect(buildpack1.reload.position).to eq(1)
              expect(buildpack2.reload.position).to eq(2)
              expect(buildpack3.reload.position).to eq(3)
            end
          end
        end
      end
    end
  end

  describe 'GET /v3/buildpacks/:guid' do
    let(:params) { {} }
    let(:buildpack) { VCAP::CloudController::Buildpack.make }

    context 'when not authenticated' do
      it 'returns 401' do
        headers = {}

        get "/v3/buildpacks/#{buildpack.guid}", params, headers

        expect(last_response.status).to eq(401)
      end
    end

    context 'when authenticated' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { headers_for(user) }

      context 'the buildpack does not exist' do
        it 'returns 404' do
          get '/v3/buildpacks/does-not-exist', params, headers
          expect(last_response.status).to eq(404)
        end

        context 'the buildpack exists' do
          it 'returns 200' do
            get "/v3/buildpacks/#{buildpack.guid}", params, headers
            expect(last_response.status).to eq(200)
          end

          it 'returns the newly-created buildpack resource' do
            get "/v3/buildpacks/#{buildpack.guid}", params, headers

            expected_response = {
              'name' => buildpack.name,
              'state' => 'AWAITING_UPLOAD',
              'stack' => buildpack.stack,
              'position' => buildpack.position,
              'enabled' => buildpack.enabled,
              'locked' => buildpack.locked,
              'guid' => buildpack.guid,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/buildpacks/#{buildpack.guid}"
                }
              }
            }
            expect(parsed_response).to be_a_response_like(expected_response)
          end
        end
      end
    end
  end
end
