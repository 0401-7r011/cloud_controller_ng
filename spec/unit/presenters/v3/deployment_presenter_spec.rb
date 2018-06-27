require 'spec_helper'
require 'presenters/v3/deployment_presenter'

module CloudController::Presenters::V3
  RSpec.describe DeploymentPresenter do
    let(:droplet) { CloudController::DropletModel.make }
    let(:app) { CloudController::AppModel.make }
    let(:deployment) { CloudController::DeploymentModel.make(app: app, droplet: droplet) }

    describe '#to_hash' do
      it 'presents the deployment as json' do
        result = DeploymentPresenter.new(deployment).to_hash
        expect(result[:guid]).to eq(deployment.guid)
        expect(result[:state]).to eq(CloudController::DeploymentModel::DEPLOYING_STATE)
        expect(result[:droplet][:guid]).to eq(droplet.guid)

        expect(result[:relationships][:app][:data][:guid]).to eq(deployment.app.guid)
        expect(result[:links][:self][:href]).to match(%r{/v3/deployments/#{deployment.guid}$})
        expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/deployments/#{deployment.guid}")
        expect(result[:links][:app][:href]).to eq("#{link_prefix}/v3/apps/#{deployment.app.guid}")
      end
    end
  end
end
