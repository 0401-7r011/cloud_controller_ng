require 'spec_helper'
require 'messages/resource_match_create_message'

RSpec.describe VCAP::CloudController::ResourceMatchCreateMessage do
  describe 'creation with v2' do
    let(:valid_v2_body) do
      StringIO.new([
        { "sha1": 'e54e24b5521df47ee1dadd28d4acecdb5d116493',
          "size": 36 },
        { "sha1": 'a9993e364706816aba3e25717850c26c9cd0d89d',
          "size": 1 }
      ].to_json)
    end

    it 'is valid if using the valid parameters' do
      expect(described_class.from_v2_fingerprints(valid_v2_body)).to be_valid
    end

    it 'can marshal data back out to the v2 fingerprint format' do
      message = described_class.from_v2_fingerprints(valid_v2_body)
      expect(message.v2_fingerprints_body.string).to eq(valid_v2_body.string)
    end
  end

  describe 'creation with v3' do
    let(:valid_v3_params) do
      {
        "resources": [
          {
            "checksum": { "value": '002d760bea1be268e27077412e11a320d0f164d3' },
            "size_in_bytes": 36
          },
          {
            "checksum": { "value": 'a9993e364706816aba3e25717850c26c9cd0d89d' },
            "size_in_bytes": 1
          }
        ]
      }
    end

    it 'is valid if using the valid parameters' do
      expect(described_class.new(valid_v3_params)).to be_valid
    end

    it 'can marshal data back out to the v2 fingerprint format' do
      message = described_class.new(valid_v3_params)
      expect(message.v2_fingerprints_body.string).to eq([
        {
          "sha1": '002d760bea1be268e27077412e11a320d0f164d3',
          "size": 36
        },
        {
          "sha1": 'a9993e364706816aba3e25717850c26c9cd0d89d',
          "size": 1
        }
      ].to_json)
    end

    describe 'validations' do
      subject { described_class.new(params) }

      context 'when the v3 resources array is too long' do
        let(:params) do
          {
            resources: Array.new(5001) do
              {
                checksum: { value: '002d760bea1be268e27077412e11a320d0f164d3' },
                size_in_bytes: 36
              }
            end
          }
        end

        it 'has the correct error message' do
          expect(subject).to be_invalid
          expect(subject.errors[:resources]).to include('is too long (maximum is 5000 characters)')
        end
      end

      context 'when the v3 checksum parameter is not a JSON object' do
        let(:params) do
          {
            resources: [
              {
                checksum: true,
                size_in_bytes: 36
              }
            ]
          }
        end

        it 'has the correct error message' do
          expect(subject).to be_invalid
          expect(subject.errors[:resources]).to include('At least one checksum is not an object')
        end
      end

      context 'when the v3 checksum value is not a string' do
        let(:params) do
          {
            resources: [
              {
                checksum: { value: false },
                size_in_bytes: 36
              }
            ]
          }
        end

        it 'has the correct error message' do
          expect(subject).to be_invalid
          expect(subject.errors[:resources]).to include('At least one checksum value is not a string')
        end
      end

      context 'when the v3 checksum value is not a valid sha1' do
        let(:params) do
          {
            resources: [
              {
                checksum: { value: 'not-a-valid-sha' },
                size_in_bytes: 36
              }
            ]
          }
        end

        it 'has the correct error message' do
          expect(subject).to be_invalid
          expect(subject.errors[:resources]).to include('At least one checksum value is not SHA-1 format')
        end
      end

      context 'when the v3 resource size is not a non-negative integer' do
        [-1, -2, true, 'x', 5.1, { size: 4 }].each do |size|
          it "has the correct error message when size is #{size}" do
            message = described_class.new({
              resources: [
                {
                  checksum: { value: '002d760bea1be268e27077412e11a320d0f164d3' },
                  size_in_bytes: size
                }
              ]
            })

            expect(message).to be_invalid
            expect(message.errors[:resources]).to include('All sizes must be non-negative integers')
          end
        end
      end
    end
  end
end
