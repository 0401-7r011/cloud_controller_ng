require 'spec_helper'
require 'actions/deployment_delete'

module VCAP::CloudController
  RSpec.describe DeploymentDelete do
    subject(:deployment_delete) { DeploymentDelete.new }

    describe '#delete' do
      let!(:deployment) { DeploymentModel.make }
      let!(:deployment2) { DeploymentModel.make }

      it 'deletes and cancels the deployment record' do
        revision = RevisionModel.make(deployment: deployment)
        deployment_delete.delete([deployment, deployment2])

        expect(deployment.exists?).to eq(false), 'Expected deployment to not exist, but it does'
        expect(deployment2.exists?).to eq(false), 'Expected deployment2 to not exist, but it does'
        expect(revision.exists?).to eq(false), 'Expected revision to not exist, but it does'
      end
    end
  end
end
