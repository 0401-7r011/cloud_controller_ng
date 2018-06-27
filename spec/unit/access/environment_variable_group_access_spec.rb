require 'spec_helper'

module CloudController
  RSpec.describe EnvironmentVariableGroupAccess, type: :access do
    subject(:access) { EnvironmentVariableGroupAccess.new(Security::AccessContext.new) }
    let(:user) { CloudController::User.make }
    let(:object) { CloudController::FeatureFlag.make }

    it_behaves_like :admin_full_access
    it_behaves_like :admin_read_only_access

    context 'a user that has cloud_controller.read' do
      before { set_current_user(user, scopes: ['cloud_controller.read']) }

      it_behaves_like :read_only_access
    end

    context 'a user that does not have cloud_controller.read' do
      before { set_current_user(user, scopes: ['cloud_controller.write']) }

      it_behaves_like :no_access
    end

    context 'a user that isnt logged in (defensive)' do
      it_behaves_like :no_access
    end
  end
end
