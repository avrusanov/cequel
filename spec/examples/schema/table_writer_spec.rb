require File.expand_path('../spec_helper', __dir__)

describe Cequel::Schema::TableWriter do
  let(:table_name) { :"posts_#{SecureRandom.hex(4)}" }

  let(:table) { cequel.schema.read_table(table_name) }

  describe '#create_table' do

    after do
      cequel.schema.drop_table(table_name)
    end

    describe 'with simple skinny table' do
      before do
        cequel.schema.create_table(table_name) do
          key :permalink, :ascii
          column :title, :text
        end
      end

      it 'creates key alias' do
        expect(table.partition_key_columns.map(&:name)).to eq([:permalink])
      end

      it 'sets key validator' do
        expect(table.partition_key_columns.map(&:type)).to eq([Cequel::Type[:ascii]])
      end

      it 'sets non-key columns' do
        expect(table.columns.find { |column| column.name == :title }.type)
          .to eq(Cequel::Type[:text])
      end
    end

    describe 'with multi-column primary key' do
      before do
        cequel.schema.create_table(table_name) do
          key :blog_subdomain, :ascii
          key :permalink, :ascii
          column :title, :text
        end
      end

      it 'creates key alias' do
        expect(table.partition_key_columns.map(&:name)).to eq([:blog_subdomain])
      end

      it 'sets key validator' do
        expect(table.partition_key_columns.map(&:type)).to eq([Cequel::Type[:ascii]])
      end

      it 'creates non-partition key components' do
        expect(table.clustering_columns.map(&:name)).to eq([:permalink])
      end

      it 'sets type for non-partition key components' do
        expect(table.clustering_columns.map(&:type)).to eq([Cequel::Type[:ascii]])
      end
    end

    describe 'with composite partition key' do
      before do
        cequel.schema.create_table(table_name) do
          partition_key :blog_subdomain, :ascii
          partition_key :permalink, :ascii
          column :title, :text
        end
      end

      it 'creates all partition key components' do
        expect(table.partition_key_columns.map(&:name)).to eq(%i[blog_subdomain permalink])
      end

      it 'sets key validators' do
        expect(table.partition_key_columns.map(&:type))
          .to eq([Cequel::Type[:ascii], Cequel::Type[:ascii]])
      end
    end

    describe 'with composite partition key and non-partition keys' do
      before do
        cequel.schema.create_table(table_name) do
          partition_key :blog_subdomain, :ascii
          partition_key :permalink, :ascii
          key :month, :timestamp
          column :title, :text
        end
      end

      it 'creates all partition key components' do
        expect(table.partition_key_columns.map(&:name))
          .to eq(%i[blog_subdomain permalink])
      end

      it 'sets key validators' do
        expect(table.partition_key_columns.map(&:type))
          .to eq([Cequel::Type[:ascii], Cequel::Type[:ascii]])
      end

      it 'creates non-partition key components' do
        expect(table.clustering_columns.map(&:name)).to eq([:month])
      end

      it 'sets type for non-partition key components' do
        expect(table.clustering_columns.map(&:type)).to eq([Cequel::Type[:timestamp]])
      end
    end

    describe 'collection types' do
      before do
        cequel.schema.create_table(table_name) do
          key :permalink, :ascii
          column :title, :text
          list :authors, :blob
          set :tags, :text
          map :trackbacks, :timestamp, :ascii
        end
      end

      it 'creates list' do
        expect(table.data_column(:authors)).to be_a(Cequel::Schema::List)
      end

      it 'sets correct type for list' do
        expect(table.data_column(:authors).type).to eq(Cequel::Type[:blob])
      end

      it 'creates set' do
        expect(table.data_column(:tags)).to be_a(Cequel::Schema::Set)
      end

      it 'sets correct type for set' do
        expect(table.data_column(:tags).type).to eq(Cequel::Type[:text])
      end

      it 'creates map' do
        expect(table.data_column(:trackbacks)).to be_a(Cequel::Schema::Map)
      end

      it 'sets correct key type' do
        expect(table.data_column(:trackbacks).key_type)
          .to eq(Cequel::Type[:timestamp])
      end

      it 'sets correct value type' do
        expect(table.data_column(:trackbacks).value_type)
          .to eq(Cequel::Type[:ascii])
      end
    end

    describe 'storage properties' do
      before do
        cequel.schema.create_table(table_name) do
          key :permalink, :ascii
          column :title, :text
          with :comment, 'Blog posts'
          with :compression,
               sstable_compression: "DeflateCompressor",
               chunk_length_kb: 64
        end
      end

      it 'sets simple properties' do
        expect(table.property(:comment)).to eq('Blog posts')
      end

      it 'sets map collection properties' do
        expect(table.property(:compression)).to include(
          chunk_length_kb: 64
        )
      end
    end

    describe 'compact storage' do
      before do
        cequel.schema.create_table(table_name) do
          key :permalink, :ascii
          column :title, :text
          compact_storage
        end
      end

      it 'has compact storage' do
        expect(table).to be_compact_storage
      end
    end

    describe 'clustering order' do
      before do
        cequel.schema.create_table(table_name) do
          key :blog_permalink, :ascii
          key :id, :uuid, :desc
          column :title, :text
        end
      end

      it 'sets clustering order' do
        expect(table.clustering_columns.map(&:clustering_order)).to eq([:desc])
      end
    end

    describe 'indices' do
      it 'creates indices' do
        cequel.schema.create_table(table_name) do
          key :blog_permalink, :ascii
          key :id, :uuid, :desc
          column :title, :text, index: true
        end
        expect(table.data_column(:title)).to be_indexed
      end

      it 'creates indices with specified name' do
        cequel.schema.create_table(table_name) do
          key :blog_permalink, :ascii
          key :id, :uuid, :desc
          column :title, :text, index: :silly_idx
        end
        expect(table.data_column(:title).index_name).to eq(:silly_idx)
      end
    end

  end

end
