require 'spec_helper'

RSpec.describe BackgroundJobEnvironment do
  before do
    allow(Steno).to receive(:init)
    TestConfig.override(
      logging: { level: 'debug2' },
      bits_service: { enabled: false },
    )
  end
  let(:config) { CloudController::Config.config }

  subject(:background_job_environment) { BackgroundJobEnvironment.new(config) }

  describe '#setup_environment' do
    before do
      allow(CloudController::DB).to receive(:load_models)
      allow(Thread).to receive(:new).and_yield
      allow(EM).to receive(:run).and_yield
      allow(CloudController::ResourcePool).to receive(:new)
    end

    it 'loads models' do
      expect(CloudController::DB).to receive(:load_models)
      background_job_environment.setup_environment
    end

    it 'configures components' do
      expect(config).to receive(:configure_components)
      background_job_environment.setup_environment
    end

    it 'configures app observer with null stager and runner' do
      expect(CloudController::ProcessObserver).to receive(:configure).with(
        instance_of(CloudController::Stagers),
        instance_of(CloudController::Runners)
      )
      background_job_environment.setup_environment
    end
  end
end
