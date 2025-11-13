require 'rails_helper'

RSpec.describe Profile, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      profile = build(:profile)
      expect(profile).to be_valid
    end

    it 'requires postal_code' do
      profile = build(:profile, postal_code: nil)
      expect(profile).not_to be_valid
      expect(profile.errors[:postal_code]).to include("can't be blank")
    end

    it 'requires province' do
      profile = build(:profile, province: nil)
      expect(profile).not_to be_valid
      expect(profile.errors[:province]).to include("can't be blank")
    end

    describe 'province inclusion' do
      it 'accepts valid Canadian provinces' do
        valid_provinces = %w[ON QC BC AB MB SK NS NB NL PE YT NT NU]

        valid_provinces.each do |province|
          profile = build(:profile, province: province)
          expect(profile).to be_valid, "Expected #{province} to be valid"
        end
      end

      it 'rejects invalid province codes' do
        invalid_provinces = [ "XX", "US", "CA", "", "Ontario", "ontario" ]

        invalid_provinces.each do |province|
          profile = build(:profile, province: province)
          expect(profile).not_to be_valid, "Expected #{province} to be invalid"
          expect(profile.errors[:province]).to include("must be a valid Canadian province/territory")
        end
      end

      it 'rejects nil province' do
        profile = build(:profile, province: nil)
        expect(profile).not_to be_valid
        expect(profile.errors[:province]).to include("can't be blank")
      end
    end
  end

  describe 'associations' do
    let(:profile) { create(:profile) }

    describe '#coverage_balances' do
      it 'has many coverage_balances' do
        expect(profile.coverage_balances).to be_empty
      end

      it 'can have multiple coverage_balances' do
        benefit1 = create(:benefit, rule_version_id: "v2024-Q1-001", category: "massage", province: profile.province)
        benefit2 = create(:benefit, :vision, rule_version_id: "v2024-Q1-002", category: "vision", province: profile.province)

        balance1 = create(:coverage_balance, profile: profile, category: "massage", rule_version_id: benefit1.rule_version_id)
        balance2 = create(:coverage_balance, :vision, profile: profile, category: "vision", rule_version_id: benefit2.rule_version_id)

        expect(profile.coverage_balances.count).to eq(2)
        expect(profile.coverage_balances).to include(balance1, balance2)
      end

      it 'destroys associated coverage_balances when profile is destroyed' do
        benefit = create(:benefit, rule_version_id: "v2024-Q1-001", category: "massage", province: profile.province)
        balance = create(:coverage_balance, profile: profile, rule_version_id: benefit.rule_version_id)

        expect { profile.destroy }.to change { CoverageBalance.count }.by(-1)
        expect(CoverageBalance.find_by(id: balance.id)).to be_nil
      end
    end
  end

  describe 'instance methods' do
    let(:profile) { create(:profile) }

    describe '#benefit_for' do
      let!(:massage_benefit) { create(:benefit, rule_version_id: "v2024-Q1-001", category: "massage", province: profile.province) }
      let!(:vision_benefit) { create(:benefit, :vision, rule_version_id: "v2024-Q1-002", category: "vision", province: profile.province) }

      it 'finds benefit by province and category' do
        found_benefit = profile.benefit_for("massage")
        expect(found_benefit).to eq(massage_benefit)
        expect(found_benefit.category).to eq("massage")
        expect(found_benefit.province).to eq(profile.province)
      end

      it 'returns correct benefit for different category' do
        found_benefit = profile.benefit_for("vision")
        expect(found_benefit).to eq(vision_benefit)
        expect(found_benefit.category).to eq("vision")
      end

      it 'returns nil when no benefit exists for category' do
        found_benefit = profile.benefit_for("dental")
        expect(found_benefit).to be_nil
      end

      it 'only returns benefits matching profile province' do
        qc_profile = create(:profile, :quebec)
        found_benefit = qc_profile.benefit_for("massage")
        expect(found_benefit).to be_nil
      end

      context 'when multiple benefits exist for same category and province' do
        let!(:another_massage_benefit) { create(:benefit, rule_version_id: "v2024-Q1-003", category: "massage", province: profile.province) }

        it 'returns the first matching benefit' do
          found_benefit = profile.benefit_for("massage")
          expect(found_benefit).to be_present
          expect(found_benefit.category).to eq("massage")
          expect(found_benefit.province).to eq(profile.province)
        end
      end
    end
  end

  describe 'data integrity' do
    it 'stores postal_code correctly' do
      profile = create(:profile, postal_code: "M5H 2N2")
      expect(profile.postal_code).to eq("M5H 2N2")
    end

    it 'stores province correctly' do
      profile = create(:profile, province: "ON")
      expect(profile.province).to eq("ON")
    end

    it 'creates timestamps automatically' do
      profile = create(:profile)
      expect(profile.created_at).to be_present
      expect(profile.updated_at).to be_present
    end
  end
end
