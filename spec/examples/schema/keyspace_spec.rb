require File.expand_path('../spec_helper', __dir__)

describe Cequel::Schema::Keyspace do
  let(:connection) do
    Cequel.connect(config)
  end
  let(:keyspace) { connection.schema }

  describe 'creating keyspace' do
    before do
      connection.configure(config)
      connection.schema.drop! if connection.schema.exists?
    end

    let(:keyspace_name) do
      test_env_number = ENV['TEST_ENV_NUMBER']
      test_env_number ?
        "cequel_schema_test_#{test_env_number}" :
        "cequel_schema_test"
    end

    let(:basic_config) do
      {
        host: Cequel::SpecSupport::Helpers.host,
        port: Cequel::SpecSupport::Helpers.port,
        keyspace: keyspace_name
      }
    end

    let(:schema_config) do
      connection.send(:cluster).tap { |x| x.refresh_schema }.keyspace(keyspace_name)
    end

    context 'with default options' do
      let(:config) { basic_config }

      it 'uses default keyspace configuration' do
        keyspace.create!
        expect(schema_config.name).to eq keyspace_name
        expect(schema_config.durable_writes?).to be true
      end
    end

    context 'with explicit options' do
      let(:config) { basic_config }

      it 'uses specified options' do
        keyspace.create! replication: { class: "SimpleStrategy", replication_factor: 2 }
        expect(schema_config.name).to eq keyspace_name
        expect(schema_config.durable_writes?).to be true
      end
    end

    context 'keeping compatibility' do
      let(:config) { basic_config }

      it 'accepts class and replication_factor options' do
        keyspace.create! class: "SimpleStrategy", replication_factor: 2
        expect(schema_config.name).to eq keyspace_name
        expect(schema_config.durable_writes?).to be true
      end

      it "raises an error if a class other than SimpleStrategy is given" do
        expect do
          keyspace.create! class: "NetworkTopologyStrategy", replication_factor: 2
        end.to raise_error(RuntimeError)
      end
    end

    context 'with custom replication options' do
      let(:config) do
        basic_config.merge(replication: { class: "SimpleStrategy", replication_factor: 3 })
      end

      it 'uses default keyspace configuration' do
        keyspace.create!
        expect(schema_config.name).to eq keyspace_name
        expect(schema_config.durable_writes?).to be true
      end
    end

    context 'with another custom replication options' do
      let(:config) do
        basic_config.merge(replication: { class: "NetworkTopologyStrategy", datacenter1: 3, datacenter2: 2 })
      end

      it 'uses default keyspace configuration' do
        keyspace.create!
        expect(schema_config.name).to eq keyspace_name
        expect(schema_config.durable_writes?).to be true
      end
    end

    context 'with custom durable_write option' do
      let(:config) do
        basic_config.merge(durable_writes: false)
      end

      it 'uses default keyspace configuration' do
        keyspace.create!
        expect(schema_config.name).to eq keyspace_name
        expect(schema_config.durable_writes?).to be false
      end
    end
  end
end
