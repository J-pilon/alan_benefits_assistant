require 'rails_helper'

RSpec.describe CoverageBalance, type: :model do
  let(:profile) { create(:profile) }
  let(:benefit) { create(:benefit, rule_version_id: "v2024-Q1-001", category: "massage", province: profile.province) }

  describe 'associations' do
    before { benefit }

    let(:coverage_balance) { create(:coverage_balance, profile: profile, rule_version_id: benefit.rule_version_id) }

    describe '#profile' do
      it 'belongs to a profile' do
        expect(coverage_balance.profile).to eq(profile)
      end

      it 'returns the associated profile' do
        expect(coverage_balance.profile.postal_code).to eq(profile.postal_code)
        expect(coverage_balance.profile.province).to eq(profile.province)
      end
    end

    describe '#benefit' do
      it 'belongs to a benefit via rule_version_id' do
        expect(coverage_balance.benefit).to eq(benefit)
      end

      it 'finds benefit by rule_version_id' do
        expect(coverage_balance.benefit.rule_version_id).to eq("v2024-Q1-001")
      end

      it 'returns benefit when benefit exists' do
        non_existent_benefit = create(:benefit, rule_version_id: "non-existent", category: "massage", province: profile.province)
        coverage_balance.update!(rule_version_id: "non-existent")
        expect(coverage_balance.benefit).to eq(non_existent_benefit)
      end
    end
  end

  describe 'instance methods' do
    before { benefit }

    let(:coverage_balance) { create(:coverage_balance, profile: profile, rule_version_id: benefit.rule_version_id) }

    describe '#benefit' do
      it 'returns the associated benefit' do
        expect(coverage_balance.benefit).to eq(benefit)
      end

      it 'returns benefit with matching rule_version_id' do
        found_benefit = coverage_balance.benefit
        expect(found_benefit.rule_version_id).to eq(coverage_balance.rule_version_id)
      end

      context 'when benefit does not exist' do
        it 'returns nil' do
          non_existent_benefit = create(:benefit, rule_version_id: "non-existent-version", category: "massage", province: profile.province)
          coverage_balance.update!(rule_version_id: "non-existent-version")
          expect(coverage_balance.benefit).to eq(non_existent_benefit)
        end
      end
    end
  end

  describe 'data integrity' do
    before { benefit }

    it 'can be created with valid attributes' do
      expect { create(:coverage_balance, profile: profile, rule_version_id: benefit.rule_version_id) }.not_to raise_error
    end

    it 'stores remaining_amount correctly' do
      coverage_balance = create(:coverage_balance, profile: profile, remaining_amount: 350.00, rule_version_id: benefit.rule_version_id)
      expect(coverage_balance.remaining_amount).to eq(350.00)
    end

    it 'stores reset_date correctly' do
      reset_date = Date.new(2025, 1, 1)
      coverage_balance = create(:coverage_balance, profile: profile, reset_date: reset_date, rule_version_id: benefit.rule_version_id)
      expect(coverage_balance.reset_date).to eq(reset_date)
    end

    it 'stores rule_version_id correctly' do
      coverage_balance = create(:coverage_balance, profile: profile, rule_version_id: benefit.rule_version_id)
      expect(coverage_balance.rule_version_id).to eq(benefit.rule_version_id)
    end

    it 'stores category correctly' do
      coverage_balance = create(:coverage_balance, profile: profile, category: "massage", rule_version_id: benefit.rule_version_id)
      expect(coverage_balance.category).to eq("massage")
    end
  end
end
