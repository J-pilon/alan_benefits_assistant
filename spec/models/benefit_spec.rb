require 'rails_helper'

RSpec.describe Benefit, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      benefit = build(:benefit)
      expect(benefit).to be_valid
    end

    it 'requires rule_version_id' do
      benefit = build(:benefit, rule_version_id: nil)
      expect(benefit).not_to be_valid
      expect(benefit.errors[:rule_version_id]).to include("can't be blank")
    end

    it 'requires unique rule_version_id' do
      create(:benefit, rule_version_id: "v2024-Q1-001")
      duplicate = build(:benefit, rule_version_id: "v2024-Q1-001")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:rule_version_id]).to include("has already been taken")
    end

    it 'requires category' do
      benefit = build(:benefit, category: nil)
      expect(benefit).not_to be_valid
      expect(benefit.errors[:category]).to include("can't be blank")
    end

    it 'requires province' do
      benefit = build(:benefit, province: nil)
      expect(benefit).not_to be_valid
      expect(benefit.errors[:province]).to include("can't be blank")
    end

    it 'requires coverage' do
      benefit = build(:benefit, coverage: nil)
      expect(benefit).not_to be_valid
      expect(benefit.errors[:coverage]).to include("can't be blank")
    end

    describe 'coverage_structure_valid' do
      it 'validates coverage includes version' do
        benefit = build(:benefit)
        benefit.coverage = benefit.coverage.except("version")
        expect(benefit).not_to be_valid
        expect(benefit.errors[:coverage]).to include("must include 'version'")
      end

      it 'validates coverage includes category' do
        benefit = build(:benefit)
        benefit.coverage = benefit.coverage.except("category")
        expect(benefit).not_to be_valid
        expect(benefit.errors[:coverage]).to include("must include 'category'")
      end

      it 'validates coverage includes province' do
        benefit = build(:benefit)
        benefit.coverage = benefit.coverage.except("province")
        expect(benefit).not_to be_valid
        expect(benefit.errors[:coverage]).to include("must include 'province'")
      end

      it 'validates coverage includes limits' do
        benefit = build(:benefit)
        benefit.coverage = benefit.coverage.except("limits")
        expect(benefit).not_to be_valid
        expect(benefit.errors[:coverage]).to include("must include 'limits'")
      end

      it 'validates coverage includes rules' do
        benefit = build(:benefit)
        benefit.coverage = benefit.coverage.except("rules")
        expect(benefit).not_to be_valid
        expect(benefit.errors[:coverage]).to include("must include 'rules'")
      end

      it 'validates coverage includes reset_period' do
        benefit = build(:benefit)
        benefit.coverage = benefit.coverage.except("reset_period")
        expect(benefit).not_to be_valid
        expect(benefit.errors[:coverage]).to include("must include 'reset_period'")
      end

      it 'validates coverage includes last_updated' do
        benefit = build(:benefit)
        benefit.coverage = benefit.coverage.except("last_updated")
        expect(benefit).not_to be_valid
        expect(benefit.errors[:coverage]).to include("must include 'last_updated'")
      end

      it 'validates category in JSON matches category column' do
        benefit = build(:benefit, category: "massage")
        benefit.coverage = benefit.coverage.merge("category" => "vision")
        expect(benefit).not_to be_valid
        expect(benefit.errors[:coverage]).to include("category in JSONB must match category column")
      end

      it 'validates province in JSON matches province column' do
        benefit = build(:benefit, province: "ON")
        benefit.coverage = benefit.coverage.merge("province" => "QC")
        expect(benefit).not_to be_valid
        expect(benefit.errors[:coverage]).to include("province in JSONB must match province column")
      end
    end
  end

  describe 'scopes' do
    let!(:massage_on) { create(:benefit, category: "massage", province: "ON") }
    let!(:massage_qc) { create(:benefit, :quebec, category: "massage") }
    let!(:vision_on) { create(:benefit, :vision, category: "vision", province: "ON") }

    describe '.by_category' do
      it 'returns benefits for the specified category' do
        expect(Benefit.by_category("massage")).to contain_exactly(massage_on, massage_qc)
      end

      it 'returns empty array for non-existent category' do
        expect(Benefit.by_category("dental")).to be_empty
      end
    end

    describe '.by_province' do
      it 'returns benefits for the specified province' do
        expect(Benefit.by_province("ON")).to contain_exactly(massage_on, vision_on)
      end

      it 'returns empty array for non-existent province' do
        expect(Benefit.by_province("BC")).to be_empty
      end
    end

    describe '.by_category_and_province' do
      it 'returns benefits matching both category and province' do
        expect(Benefit.by_category_and_province("massage", "ON")).to contain_exactly(massage_on)
      end

      it 'returns empty array when no match' do
        expect(Benefit.by_category_and_province("vision", "QC")).to be_empty
      end
    end

    describe '.recent' do
      it 'orders by updated_at descending' do
        massage_on.update!(updated_at: 2.days.ago)
        vision_on.update!(updated_at: 1.day.ago)
        massage_qc.update!(updated_at: 3.days.ago)

        expect(Benefit.recent.pluck(:id)).to eq([ vision_on.id, massage_on.id, massage_qc.id ])
      end
    end

    describe '.stale' do
      it 'returns benefits updated more than 90 days ago' do
        stale_benefit = create(:benefit, :stale)
        recent_benefit = create(:benefit, updated_at: 89.days.ago)

        expect(Benefit.stale).to include(stale_benefit)
        expect(Benefit.stale).not_to include(recent_benefit)
      end
    end
  end

  describe 'instance methods' do
    let(:benefit) { create(:benefit) }

    describe '#version' do
      it 'returns version from coverage JSON' do
        expect(benefit.version).to eq(benefit.rule_version_id)
      end
    end

    describe '#annual_max' do
      it 'returns annual_max from coverage limits' do
        expect(benefit.annual_max).to eq(500.00)
      end
    end

    describe '#per_visit_max' do
      it 'returns per_visit_max from coverage limits' do
        expect(benefit.per_visit_max).to eq(100.00)
      end
    end

    describe '#visits_per_year' do
      it 'returns visits_per_year from coverage limits' do
        expect(benefit.visits_per_year).to eq(10)
      end
    end

    describe '#rule_bullets' do
      it 'returns array of rule descriptions' do
        expected = [ "Maximum $500 per calendar year", "Maximum $100 per massage session", "Up to 10 visits per calendar year" ]
        expect(benefit.rule_bullets).to eq(expected)
      end

      it 'returns empty array when rules are missing' do
        benefit.coverage = benefit.coverage.except("rules")
        expect(benefit.rule_bullets).to eq([])
      end
    end

    describe '#why_text' do
      it 'returns formatted rule explanations' do
        expected = "annual_limit: Maximum $500 per calendar year; per_visit_limit: Maximum $100 per massage session; visit_limit: Up to 10 visits per calendar year"
        expect(benefit.why_text).to eq(expected)
      end

      it 'returns empty string when rules are missing' do
        benefit.coverage = benefit.coverage.except("rules")
        expect(benefit.why_text).to eq("")
      end
    end

    describe '#reset_period' do
      it 'returns reset_period from coverage JSON' do
        expect(benefit.reset_period).to eq("calendar_year")
      end
    end

    describe '#eligible_providers' do
      it 'returns eligible_providers from coverage restrictions' do
        expect(benefit.eligible_providers).to eq([ "RMT", "Massage Therapist" ])
      end

      it 'returns empty array when restrictions are missing' do
        benefit.coverage = benefit.coverage.except("restrictions")
        expect(benefit.eligible_providers).to eq([])
      end
    end

    describe '#exclusions' do
      it 'returns exclusions from coverage restrictions' do
        expect(benefit.exclusions).to eq([ "Spa services", "Hot stone massage" ])
      end

      it 'returns empty array when restrictions are missing' do
        benefit.coverage = benefit.coverage.except("restrictions")
        expect(benefit.exclusions).to eq([])
      end
    end

    describe '#requires_referral?' do
      it 'returns requires_referral from coverage restrictions' do
        expect(benefit.requires_referral?).to eq(false)
      end

      it 'returns false when restrictions are missing' do
        benefit.coverage = benefit.coverage.except("restrictions")
        expect(benefit.requires_referral?).to eq(false)
      end
    end

    describe '#stale?' do
      it 'returns true when updated_at is more than 90 days ago' do
        benefit.update!(updated_at: 91.days.ago)
        expect(benefit.stale?).to be true
      end

      it 'returns false when updated_at is less than 90 days ago' do
        benefit.update!(updated_at: 89.days.ago)
        expect(benefit.stale?).to be false
      end
    end
  end
end
