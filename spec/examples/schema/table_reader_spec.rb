require File.expand_path('../spec_helper', __dir__)

describe Cequel::Schema::TableReader do
  let(:table_name) { :"posts_#{SecureRandom.hex(4)}" }

  after do
    cequel.schema.drop_table(table_name)
  end

  describe ".read(keyspace, table_name)" do
    before do
      cequel.execute("CREATE TABLE #{table_name} (permalink text PRIMARY KEY)")
      cequel.send(:cluster).refresh_schema
    end

    it "returns a table" do
      expect(
        described_class.read(cequel, table_name)
      ).to be_a Cequel::Schema::Table
    end
  end

  describe "#call" do
    let(:table) { described_class.new(fetch_table_data).call }

    context 'simple key' do
      before do
        cequel.execute("CREATE TABLE #{table_name} (permalink text PRIMARY KEY)")
        cequel.send(:cluster).refresh_schema
      end

      it 'reads name correctly' do
        expect(table.partition_key_columns.first.name).to eq(:permalink)
      end

      it 'reads type correctly' do
        expect(table.partition_key_columns.first.type).to be_a(Cequel::Type::Text)
      end

      it 'has no nonpartition keys' do
        expect(table.clustering_columns).to be_empty
      end
    end

    context 'single cluster key' do
      before do
        cequel.execute <<-CQL
        CREATE TABLE #{table_name} (
          blog_subdomain text,
          permalink ascii,
          PRIMARY KEY (blog_subdomain, permalink)
        )
        CQL
      end

      it 'reads partition key name' do
        expect(table.partition_key_columns.map(&:name)).to eq([:blog_subdomain])
      end

      it 'reads partition key type' do
        expect(table.partition_key_columns.map(&:type)).to eq([Cequel::Type::Text.instance])
      end

      it 'reads non-partition key name' do
        expect(table.clustering_columns.map(&:name)).to eq([:permalink])
      end

      it 'reads non-partition key type' do
        expect(table.clustering_columns.map(&:type))
          .to eq([Cequel::Type::Ascii.instance])
      end

      it 'defaults clustering order to asc' do
        expect(table.clustering_columns.map(&:clustering_order)).to eq([:asc])
      end
    end

    context 'reverse-ordered cluster key' do
      before do
        cequel.execute <<-CQL
        CREATE TABLE #{table_name} (
          blog_subdomain text,
          permalink ascii,
          PRIMARY KEY (blog_subdomain, permalink)
        )
        WITH CLUSTERING ORDER BY (permalink DESC)
        CQL
      end

      it 'reads non-partition key name' do
        expect(table.clustering_columns.map(&:name)).to eq([:permalink])
      end

      it 'reads non-partition key type' do
        expect(table.clustering_columns.map(&:type))
          .to eq([Cequel::Type::Ascii.instance])
      end

      it 'recognizes reversed clustering order' do
        expect(table.clustering_columns.map(&:clustering_order)).to eq([:desc])
      end
    end

    context 'compound cluster key' do
      before do
        cequel.execute <<-CQL
        CREATE TABLE #{table_name} (
          blog_subdomain text,
          permalink ascii,
          author_id uuid,
          PRIMARY KEY (blog_subdomain, permalink, author_id)
        )
        WITH CLUSTERING ORDER BY (permalink DESC, author_id ASC)
        CQL
      end

      it 'reads non-partition key names' do
        expect(table.clustering_columns.map(&:name)).to eq(%i[permalink author_id])
      end

      it 'reads non-partition key types' do
        expect(table.clustering_columns.map(&:type))
          .to eq([Cequel::Type::Ascii.instance, Cequel::Type::Uuid.instance])
      end

      it 'reads heterogeneous clustering orders' do
        expect(table.clustering_columns.map(&:clustering_order)).to eq(%i[desc asc])
      end
    end

    context 'compound partition key' do
      before do
        cequel.execute <<-CQL
        CREATE TABLE #{table_name} (
          blog_subdomain text,
          permalink ascii,
          PRIMARY KEY ((blog_subdomain, permalink))
        )
        CQL
      end

      it 'reads partition key names' do
        expect(table.partition_key_columns.map(&:name)).to eq(%i[blog_subdomain permalink])
      end

      it 'reads partition key types' do
        expect(table.partition_key_columns.map(&:type))
          .to eq([Cequel::Type::Text.instance, Cequel::Type::Ascii.instance])
      end

      it 'has empty nonpartition keys' do
        expect(table.clustering_columns).to be_empty
      end

    end

    context 'compound partition and cluster keys' do
      before do
        cequel.execute <<-CQL
        CREATE TABLE #{table_name} (
          blog_subdomain text,
          permalink ascii,
          author_id uuid,
          published_at timestamp,
          PRIMARY KEY ((blog_subdomain, permalink), author_id, published_at)
        )
        WITH CLUSTERING ORDER BY (author_id ASC, published_at DESC)
        CQL
      end

      it 'reads partition key names' do
        expect(table.partition_key_columns.map(&:name)).to eq(%i[blog_subdomain permalink])
      end

      it 'reads partition key types' do
        expect(table.partition_key_columns.map(&:type))
          .to eq([Cequel::Type::Text.instance, Cequel::Type::Ascii.instance])
      end

      it 'reads non-partition key names' do
        expect(table.clustering_columns.map(&:name))
          .to eq(%i[author_id published_at])
      end

      it 'reads non-partition key types' do
        expect(table.clustering_columns.map(&:type)).to eq(
          [Cequel::Type::Uuid.instance, Cequel::Type::Timestamp.instance]
        )
      end

      it 'reads clustering order' do
        expect(table.clustering_columns.map(&:clustering_order)).to eq(%i[asc desc])
      end

    end

    context 'data columns' do

      before do
        cequel.execute <<-CQL
          CREATE TABLE #{table_name} (
            blog_subdomain text,
            permalink ascii,
            title text,
            author_id uuid,
            categories LIST <text>,
            tags SET <text>,
            trackbacks MAP <timestamp,ascii>,
            PRIMARY KEY (blog_subdomain, permalink)
          )
        CQL
        cequel.execute("CREATE INDEX posts_author_id_idx ON #{table_name} (author_id)")
      end

      it 'reads types of scalar data columns' do
        expect(table.data_columns.find { |column| column.name == :title }.type)
          .to eq(Cequel::Type[:text])
        expect(table.data_columns.find { |column| column.name == :author_id }.type)
          .to eq(Cequel::Type[:uuid])
      end

      it 'reads index attributes' do
        expect(table.data_columns.find { |column| column.name == :author_id }.index_name)
          .to eq(:posts_author_id_idx)
      end

      it 'leaves nil index for non-indexed columns' do
        expect(table.data_columns.find { |column| column.name == :title }.index_name)
          .to be_nil
      end

      it 'reads list columns' do
        expect(table.data_columns.find { |column| column.name == :categories })
          .to be_a(Cequel::Schema::List)
      end

      it 'reads list column type' do
        expect(table.data_columns.find { |column| column.name == :categories }.type)
          .to eq(Cequel::Type[:text])
      end

      it 'reads set columns' do
        expect(table.data_columns.find { |column| column.name == :tags })
          .to be_a(Cequel::Schema::Set)
      end

      it 'reads set column type' do
        expect(table.data_columns.find { |column| column.name == :tags }.type)
          .to eq(Cequel::Type[:text])
      end

      it 'reads map columns' do
        expect(table.data_columns.find { |column| column.name == :trackbacks })
          .to be_a(Cequel::Schema::Map)
      end

      it 'reads map column key type' do
        expect(table.data_columns.find { |column| column.name == :trackbacks }.key_type)
          .to eq(Cequel::Type[:timestamp])
      end

      it 'reads map column value type' do
        expect(table.data_columns.find { |column| column.name == :trackbacks }
                .value_type).to eq(Cequel::Type[:ascii])
      end

    end

    context 'storage properties' do

      before do
        cequel.execute <<-CQL
          CREATE TABLE #{table_name} (permalink text PRIMARY KEY)
          WITH bloom_filter_fp_chance = 0.02
          AND comment = 'Posts table'
          AND compaction = {
            'class' : 'SizeTieredCompactionStrategy',
            'bucket_high' : 1.8,
            'max_threshold' : 64,
            'min_sstable_size' : 50,
            'tombstone_compaction_interval' : 2
          } AND compression = {
            'sstable_compression' : 'DeflateCompressor',
            'chunk_length_kb' : 128,
            'crc_check_chance' : 0.5
          }
        CQL
      end

      it 'reads float properties' do
        expect(table.property(:bloom_filter_fp_chance)).to eq(0.02)
      end

      it 'reads string properties' do
        expect(table.property(:comment)).to eq('Posts table')
      end

      it 'reads and simplify compaction class' do
        expect(table.property(:compaction)[:class])
          .to eq('SizeTieredCompactionStrategy')
      end

      it 'reads float properties from compaction hash' do
        expect(table.property(:compaction)[:bucket_high]).to eq(1.8)
      end

      it 'reads integer properties from compaction hash' do
        expect(table.property(:compaction)[:max_threshold]).to eq(64)
      end

      it 'reads and simplify compression class' do
        expect(table.property(:compression)[:sstable_compression] ||
               table.property(:compression)[:class])
          .to eq('DeflateCompressor')
      end

      it 'reads integer properties from compression class' do
        expect(table.property(:compression)[:chunk_length_kb]).to eq(128)
      end

      it 'reads float properties from compression class' do
        expect(table.property(:compression)[:crc_check_chance]).to eq(0.5)
      end

      it 'recognizes no compact storage' do
        expect(table).not_to be_compact_storage
      end
    end

    context 'skinny-row compact storage' do
      subject { table }

      before do
        cequel.execute <<-CQL
          CREATE TABLE #{table_name} (permalink text PRIMARY KEY, title text, body text)
          WITH COMPACT STORAGE
        CQL
      end

      it { is_expected.to be_compact_storage }

      its(:partition_key_columns) do
        is_expected.to eq([Cequel::Schema::PartitionKey.new(:permalink, :text)])
      end

      its(:clustering_columns) { is_expected.to be_empty }

      specify do 
        expect(table.data_columns).to contain_exactly(
          Cequel::Schema::DataColumn.new(:title, :text),
          Cequel::Schema::DataColumn.new(:body, :text)
        )
      end
    end

    context 'wide-row compact storage' do
      subject { table }

      before do
        cequel.execute <<-CQL
          CREATE TABLE #{table_name} (
            blog_subdomain text,
            id uuid,
            data text,
            PRIMARY KEY (blog_subdomain, id)
          )
          WITH COMPACT STORAGE
        CQL
      end

      it { is_expected.to be_compact_storage }

      its(:partition_key_columns) do
        is_expected.to eq([Cequel::Schema::PartitionKey.new(:blog_subdomain, :text)])
      end

      its(:clustering_columns) do
        is_expected.to eq([Cequel::Schema::ClusteringColumn.new(:id, :uuid)])
      end

      its(:data_columns) do
        is_expected.to eq([Cequel::Schema::DataColumn.new(:data, :text)])
      end
    end

    context 'materialized view exists', cql: '~> 3.4' do
      let!(:name) { table_name }
      let(:view_name) { "#{name}_view" }
      let(:view) { described_class.new(fetch_view_data).call }

      before do
        cequel.execute <<-CQL
          CREATE TABLE #{table_name} (
            blog_subdomain text,
            permalink ascii,
            PRIMARY KEY (blog_subdomain, permalink)
          )
        CQL
        cequel.execute <<-CQL
          CREATE MATERIALIZED VIEW #{view_name} AS
            SELECT blog_subdomain, permalink
            FROM #{name}
            WHERE blog_subdomain IS NOT NULL AND permalink IS NOT NULL
            PRIMARY KEY ( blog_subdomain, permalink )
        CQL
      end

      after do
        cequel.schema.drop_materialized_view(view_name)
      end

      it "recognizes that regular tables are not views" do
        expect(table.materialized_view?).to be false
      end

      it "recognizes thats view tables are views" do
        expect(view.materialized_view?).to be true
      end
    end

    context 'skinny-row legacy table', :thrift do
      subject { table }

      before do
        legacy_connection.execute <<-CQL
          CREATE TABLE #{table_name} (permalink text PRIMARY KEY, title text, body text)
        CQL
      end

      it { is_expected.to be_compact_storage }

      its(:partition_key_columns) do 
        is_expected.to eq(
          [Cequel::Schema::PartitionKey.new(:permalink, :text)]
        )
      end

      its(:clustering_columns) { is_expected.to be_empty }

      its(:data_columns) do 
        is_expected.to contain_exactly(Cequel::Schema::DataColumn.new(:title, :text), 
                                       Cequel::Schema::DataColumn.new(:body, :text))
      end
    end

    context 'wide-row legacy table', :thrift do
      subject { table }

      before do
        legacy_connection.execute(<<-CQL2)
          CREATE COLUMNFAMILY #{table_name} (blog_subdomain text PRIMARY KEY)
          WITH comparator=uuid AND default_validation=text
        CQL2
      end

      it { is_expected.to be_compact_storage }

      its(:partition_key_columns) do 
        is_expected.to eq(
          [Cequel::Schema::PartitionKey.new(:blog_subdomain, :text)]
        )
      end

      its(:clustering_columns) do 
        is_expected.to eq(
          [Cequel::Schema::ClusteringColumn.new(:column1, :uuid)]
        )
      end

      its(:data_columns) do 
        is_expected.to eq(
          [Cequel::Schema::DataColumn.new(:value, :text)]
        )
      end
    end
  end

  def fetch_table_data(name=table_name)
    cequel.send(:cluster).refresh_schema
    cequel.send(:cluster)
          .keyspace(cequel.name.to_s)
          .table(name.to_s)
  end

  def fetch_view_data(name=view_name)
    cequel.send(:cluster).refresh_schema
    cequel.send(:cluster)
          .keyspace(cequel.name.to_s)
          .materialized_view(name.to_s)
  end
end
