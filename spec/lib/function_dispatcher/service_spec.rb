require 'rails_helper'

RSpec.describe FunctionDispatcher::Service do
  let(:test_yaml_path) { Rails.root.join("spec", "fixtures", "dispatch_functions.yml").to_s }
  let(:config) do
    FunctionDispatcher::Configuration.new.tap do |c|
      c.yaml_file_path = test_yaml_path
      c.enabled_functions = :all
      c.context_required = true
    end
  end
  let(:service) { described_class.new(config: config) }

  describe '#initialize' do
    it 'loads and registers functions from YAML file' do
      expect(service.registry.all).not_to be_empty
    end

    it 'uses default registry if none provided' do
      service = described_class.new(config: config)
      expect(service.registry).to be_a(FunctionDispatcher::FunctionRegistry)
    end

    it 'uses default config if none provided' do
      service = described_class.new
      expect(service.config).to be_a(FunctionDispatcher::Configuration)
    end

    it 'registers expected functions from fixtures' do
      function_names = service.registry.all.map(&:name)
      expect(function_names).to include(:coverage_balances_read)
      expect(function_names).to include(:coverage_rules_explain)
    end
  end

  describe '#dispatch' do
    let(:profile) { create(:profile) }
    let(:context) { { profile: profile } }

    context 'with valid function and parameters' do
      let!(:balance) do
        create(:coverage_balance,
          profile: profile,
          category: "massage",
          remaining_amount: 500.0,
          reset_date: Date.new(2024, 12, 31))
      end

      it 'successfully dispatches coverage_balances_read' do
        result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        expect(result.successful?).to be true
        expect(result.data).to be_present
        expect(result.data[:category]).to eq("massage")
        expect(result.data[:remaining_amount]).to eq(500.0)
      end

      it 'accepts string function names' do
        result = service.dispatch("coverage_balances_read", { category: "massage" }, context)

        expect(result.successful?).to be true
        expect(result.data).to be_present
      end

      it 'accepts string parameter keys' do
        result = service.dispatch(:coverage_balances_read, { "category" => "massage" }, context)

        expect(result.successful?).to be true
        expect(result.data[:category]).to eq("massage")
      end

      it 'accepts symbol parameter keys' do
        result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        expect(result.successful?).to be true
        expect(result.data[:category]).to eq("massage")
      end
    end

    context 'with get_benefit_coverage function' do
      let!(:benefit) do
        create(:benefit,
          category: "vision",
          province: profile.province,
          rule_version_id: "v2024-Q1-002")
      end

      it 'successfully retrieves benefit coverage data' do
        result = service.dispatch(:coverage_rules_explain, { category: "vision" }, context)

        expect(result.successful?).to be true
        expect(result.data).to be_present
        expect(result.data).to have_key("version")
      end
    end

    context 'when function does not exist' do
      it 'returns error result' do
        result = service.dispatch(:nonexistent_function, {}, context)

        expect(result.failure?).to be true
        expect(result.error).to include("not found")
      end

      it 'includes function name in error message' do
        result = service.dispatch(:invalid_func, {}, context)

        expect(result.error).to include("invalid_func")
      end
    end

    context 'when function is disabled' do
      let(:config) do
        FunctionDispatcher::Configuration.new.tap do |c|
          c.yaml_file_path = test_yaml_path
          c.enabled_functions = [ :coverage_rules_explain ]
          c.context_required = true
        end
      end

      it 'returns error for disabled function' do
        result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        expect(result.failure?).to be true
        expect(result.error).to include("disabled")
      end

      it 'allows dispatching enabled functions' do
        benefit = create(:benefit, category: "massage", province: profile.province)

        result = service.dispatch(:coverage_rules_explain, { category: "massage" }, context)

        expect(result.successful?).to be true
      end
    end

    context 'with parameter validation' do
      it 'returns error when required parameter is missing' do
        result = service.dispatch(:coverage_balances_read, {}, context)

        expect(result.failure?).to be true
        expect(result.error).to include("Missing required parameters")
        expect(result.error).to include("category")
      end

      it 'returns error for invalid enum value' do
        result = service.dispatch(:coverage_balances_read, { category: "invalid_category" }, context)

        expect(result.failure?).to be true
        expect(result.error).to include("Invalid value")
      end

      it 'accepts valid enum values' do
        create(:coverage_balance, profile: profile, category: "dental")

        result = service.dispatch(:coverage_balances_read, { category: "dental" }, context)

        expect(result.successful?).to be true
      end

      it 'validates all allowed enum values' do
        %w[massage vision dental].each do |category|
          create(:coverage_balance, profile: profile, category: category)
          result = service.dispatch(:coverage_balances_read, { category: category }, context)
          expect(result.successful?).to be true
        end
      end
    end

    context 'with context requirements' do
      it 'returns error when profile context is missing' do
        result = service.dispatch(:coverage_balances_read, { category: "massage" }, {})

        expect(result.failure?).to be true
        expect(result.error).to include("Profile context is required")
      end

      it 'returns error when context is nil' do
        result = service.dispatch(:coverage_balances_read, { category: "massage" }, { profile: nil })

        expect(result.failure?).to be true
        expect(result.error).to include("Profile context is required")
      end

      it 'succeeds when context is properly provided' do
        create(:coverage_balance, profile: profile, category: "massage")

        result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        expect(result.successful?).to be true
      end
    end

    context 'when context_required is false' do
      let(:config) do
        FunctionDispatcher::Configuration.new.tap do |c|
          c.yaml_file_path = test_yaml_path
          c.enabled_functions = :all
          c.context_required = false
        end
      end

      it 'allows dispatch without profile context' do
        # This will still fail at executor level but won't fail at service validation
        result = service.dispatch(:coverage_balances_read, { category: "massage" }, {})

        # The service accepts it, but the executor requires profile
        expect(result.failure?).to be true
        expect(result.error).to include("Profile is required")
      end
    end

    context 'with execution errors' do
      it 'handles executor errors gracefully' do
        allow(FunctionDispatcher::Executors::GetCoverageBalanceExecutor)
          .to receive(:call).and_raise(StandardError.new("Database error"))

        result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        expect(result.failure?).to be true
        expect(result.error).to include("Execution failed")
      end

      it 'returns error when data not found' do
        # Profile has no balance for this category
        result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        expect(result.failure?).to be true
        expect(result.error).to include("No data found")
      end
    end
  end

  describe '#sanitized_function_definitions' do
    it 'returns array of function definitions' do
      definitions = service.sanitized_function_definitions

      expect(definitions).to be_an(Array)
      expect(definitions).not_to be_empty
    end

    it 'includes function name for each definition' do
      definitions = service.sanitized_function_definitions

      definitions.each do |def_hash|
        expect(def_hash).to have_key(:name)
        expect(def_hash[:name]).to be_present
      end
    end

    it 'includes description for each definition' do
      definitions = service.sanitized_function_definitions

      definitions.each do |def_hash|
        expect(def_hash).to have_key(:description)
        expect(def_hash[:description]).to be_a(String)
      end
    end

    it 'includes params_schema for each definition' do
      definitions = service.sanitized_function_definitions

      definitions.each do |def_hash|
        expect(def_hash).to have_key(:params_schema)
      end
    end

    it 'returns expected function names' do
      definitions = service.sanitized_function_definitions
      names = definitions.map { |d| d[:name] }

      expect(names).to include(:coverage_balances_read)
      expect(names).to include(:coverage_rules_explain)
    end

    it 'includes parameter schema with properties' do
      definitions = service.sanitized_function_definitions
      balance_def = definitions.find { |d| d[:name] == :coverage_balances_read }

      expect(balance_def[:params_schema]).to be_present
      expect(balance_def[:params_schema]["properties"]).to have_key("category")
    end

    it 'includes enum values in schema' do
      definitions = service.sanitized_function_definitions
      balance_def = definitions.find { |d| d[:name] == :coverage_balances_read }

      category_schema = balance_def[:params_schema]["properties"]["category"]
      expect(category_schema["enum"]).to include("massage", "vision", "dental")
    end
  end

  describe 'integration tests' do
    let(:profile) { create(:profile, province: "ON") }
    let(:context) { { profile: profile } }

    context 'complete workflow for coverage balance query' do
      it 'processes balance query from start to finish' do
        # Setup: Create test data
        balance = create(:coverage_balance,
          profile: profile,
          category: "massage",
          remaining_amount: 350.0,
          reset_date: Date.new(2024, 12, 31),
          rule_version_id: "v2024-Q1-001")

        # Action: Dispatch the function
        result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        # Assert: Verify complete result structure
        expect(result.successful?).to be true
        expect(result.data).to be_a(Hash)
        expect(result.data[:category]).to eq("massage")
        expect(result.data[:remaining_amount]).to eq(350.0)
        expect(result.data[:reset_date]).to eq(Date.new(2024, 12, 31))
        expect(result.data[:rule_version_id]).to eq("v2024-Q1-001")
      end
    end

    context 'complete workflow for coverage rules query' do
      it 'processes coverage rules query from start to finish' do
        # Setup: Create benefit with coverage rules
        benefit = create(:benefit, :vision,
          province: profile.province,
          category: "vision",
          rule_version_id: "v2024-Q1-002")

        # Action: Dispatch the function
        result = service.dispatch(:coverage_rules_explain, { category: "vision" }, context)

        # Assert: Verify complete result structure
        expect(result.successful?).to be true
        expect(result.data).to be_a(Hash)
        expect(result.data["version"]).to eq("v2024-Q1-002")
        expect(result.data["category"]).to eq("vision")
        expect(result.data["limits"]).to be_present
        expect(result.data["restrictions"]).to be_present
      end
    end

    context 'handling multiple categories' do
      it 'dispatches different categories successfully' do
        # Setup multiple balances
        create(:coverage_balance, profile: profile, category: "massage", remaining_amount: 500.0)
        create(:coverage_balance, profile: profile, category: "vision", remaining_amount: 150.0)
        create(:coverage_balance, profile: profile, category: "dental", remaining_amount: 1200.0)

        # Test each category
        massage_result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)
        vision_result = service.dispatch(:coverage_balances_read, { category: "vision" }, context)
        dental_result = service.dispatch(:coverage_balances_read, { category: "dental" }, context)

        expect(massage_result.data[:remaining_amount]).to eq(500.0)
        expect(vision_result.data[:remaining_amount]).to eq(150.0)
        expect(dental_result.data[:remaining_amount]).to eq(1200.0)
      end
    end

    context 'error recovery scenarios' do
      it 'handles missing data gracefully across multiple requests' do
        # Only create one balance
        create(:coverage_balance, profile: profile, category: "massage")

        massage_result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)
        vision_result = service.dispatch(:coverage_balances_read, { category: "vision" }, context)

        expect(massage_result.successful?).to be true
        expect(vision_result.failure?).to be true
        expect(vision_result.error).to include("No data found")
      end

      it 'maintains service state after errors' do
        # First request fails
        failed_result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)
        expect(failed_result.failure?).to be true

        # Create data and retry
        create(:coverage_balance, profile: profile, category: "massage", remaining_amount: 300.0)
        success_result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        expect(success_result.successful?).to be true
        expect(success_result.data[:remaining_amount]).to eq(300.0)
      end
    end

    context 'with different profiles' do
      let(:profile1) { create(:profile, province: "ON") }
      let(:profile2) { create(:profile, province: "QC") }

      it 'dispatches correctly for different profiles' do
        balance1 = create(:coverage_balance, profile: profile1, category: "massage", remaining_amount: 500.0)
        balance2 = create(:coverage_balance, profile: profile2, category: "massage", remaining_amount: 750.0)

        result1 = service.dispatch(:coverage_balances_read, { category: "massage" }, { profile: profile1 })
        result2 = service.dispatch(:coverage_balances_read, { category: "massage" }, { profile: profile2 })

        expect(result1.data[:remaining_amount]).to eq(500.0)
        expect(result2.data[:remaining_amount]).to eq(750.0)
      end
    end
  end
end
