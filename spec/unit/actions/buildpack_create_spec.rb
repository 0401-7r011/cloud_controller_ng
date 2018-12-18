require 'spec_helper'
require 'actions/buildpack_create'
require 'messages/buildpack_create_message'

module VCAP::CloudController
  RSpec.describe BuildpackCreate do
    describe 'create' do
        let!(:buildpack1) { Buildpack.create(name: 'take-up-position-1', position: 1) }
        let!(:buildpack2) { Buildpack.create(name: 'take-up-position-2', position: 2) }
        let!(:buildpack3) { Buildpack.create(name: 'take-up-position-3', position: 3) }
       before do
        Stack.create(name: 'the-stack')
      end

      context 'when position is not provided' do
        it 'creates a buildpack' do
          message = BuildpackCreateMessage.new(
            name: 'the-name',
            stack: 'the-stack',
            enabled: false,
            locked: true,
          )
          buildpack = BuildpackCreate.new.create(message)

          expect(buildpack.name).to eq('the-name')
          expect(buildpack.stack).to eq('the-stack')
          expect(buildpack.position).to eq(1)
          expect(buildpack.enabled).to eq(false)
          expect(buildpack.locked).to eq(true)
        end
      end

      context 'when position is provided' do
        context 'when position is between 1 and number of buildpacks' do
          it 'creates a buildpack' do
            message = BuildpackCreateMessage.new(
              name: 'the-name',
              position: 2,
            )
            buildpack = BuildpackCreate.new.create(message)

            expect(buildpack.position).to eq(2)
            expect(buildpack1.reload.position).to eq(1)
            expect(buildpack2.reload.position).to eq(3)
            expect(buildpack3.reload.position).to eq(4)
          end
        end

        context 'when position is greater than number of buildpacks' do
          it 'creates a buildpack' do
            message = BuildpackCreateMessage.new(
              name: 'the-name',
              position: 42,
            )
            buildpack = BuildpackCreate.new.create(message)

            expect(buildpack.position).to eq(4)
          end
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(Buildpack).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = BuildpackCreateMessage.new(name: 'foobar')
          expect {
            BuildpackCreate.new.create(message)
          }.to raise_error(BuildpackCreate::Error, 'blork is busted')
        end
      end

      context 'when the associated stack does not exist' do
        it 'raises a human-friendly error' do
          message = BuildpackCreateMessage.new(name: 'the-name', stack: 'does-not-exist')

          expect {
            BuildpackCreate.new.create(message)
          }.to raise_error(BuildpackCreate::Error, "Stack 'does-not-exist' does not exist")
        end
      end

      context 'when there is a uniqueness error' do
        let(:name) { 'the-name' }

        context 'and stack is nil' do
          before do
            Buildpack.create(name: name, stack: nil)
          end

          it 'raises a human-friendly error' do
            message = BuildpackCreateMessage.new(name: name)
            expect {
              BuildpackCreate.new.create(message)
            }.to raise_error(BuildpackCreate::Error, "The buildpack name 'the-name' with an unassigned stack is already in use")
          end
        end

        context 'and stack is present' do
          before do
            Buildpack.create(name: name, stack: 'the-stack')
          end

          it 'raises a human-friendly error' do
            message = BuildpackCreateMessage.new(name: name, stack: 'the-stack')
            expect {
              BuildpackCreate.new.create(message)
            }.to raise_error(BuildpackCreate::Error, "The buildpack name 'the-name' with the stack 'the-stack' is already in use")
          end
        end
      end
    end
  end
end
