require File.expand_path('spec_helper', __dir__)

describe Cequel::Type do

  describe 'ascii' do
    subject { described_class[:ascii] }

    its(:cql_name) { is_expected.to eq(:ascii) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.AsciiType')
    end

    describe '#cast' do
      specify do 
        expect(subject.cast('hey'.encode('UTF-8')).encoding.name)
          .to eq('US-ASCII')
      end
    end
  end

  describe 'blob' do
    subject { described_class[:blob] }

    its(:cql_name) { is_expected.to eq(:blob) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.BytesType')
    end

    describe '#cast' do
      specify { expect(subject.cast(123)).to eq(123.to_s(16)) }
      specify { expect(subject.cast(123).encoding.name).to eq('ASCII-8BIT') }
      specify { expect(subject.cast('2345').encoding.name).to eq('ASCII-8BIT') }
    end
  end

  describe 'boolean' do
    subject { described_class[:boolean] }

    its(:cql_name) { is_expected.to eq(:boolean) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.BooleanType')
    end

    describe '#cast' do
      specify { expect(subject.cast(true)).to be(true) }
      specify { expect(subject.cast(false)).to be(false) }
      specify { expect(subject.cast(1)).to be(true) }
    end
  end

  describe 'counter' do
    subject { described_class[:counter] }

    its(:cql_name) { is_expected.to eq(:counter) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.CounterColumnType')
    end

    describe '#cast' do
      specify { expect(subject.cast(1)).to eq(1) }
      specify { expect(subject.cast('1')).to eq(1) }
    end
  end

  describe 'decimal' do
    subject { described_class[:decimal] }

    its(:cql_name) { is_expected.to eq(:decimal) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.DecimalType')
    end

    describe '#cast' do
      specify { expect(subject.cast(1)).to eql(BigDecimal('1.0')) }
      specify { expect(subject.cast(1.0)).to eql(BigDecimal('1.0')) }
      specify { expect(subject.cast(1.0.to_r)).to eql(BigDecimal('1.0')) }
      specify { expect(subject.cast('1')).to eql(BigDecimal('1.0')) }
    end
  end

  describe 'double' do
    subject { described_class[:double] }

    its(:cql_name) { is_expected.to eq(:double) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.DoubleType')
    end

    describe '#cast' do
      specify { expect(subject.cast(1.0)).to be(1.0) }
      specify { expect(subject.cast(1)).to be(1.0) }
      specify { expect(subject.cast(1.0.to_r)).to be(1.0) }
      specify { expect(subject.cast('1.0')).to be(1.0) }
      specify { expect(subject.cast(BigDecimal('1.0'))).to be(1.0) }
    end
  end

  describe 'float' do
    subject { described_class[:float] }

    its(:cql_name) { is_expected.to eq(:float) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.FloatType')
    end

    describe '#cast' do
      specify { expect(subject.cast(1.0)).to be(1.0) }
      specify { expect(subject.cast(1)).to be(1.0) }
      specify { expect(subject.cast(1.0.to_r)).to be(1.0) }
      specify { expect(subject.cast('1.0')).to be(1.0) }
      specify { expect(subject.cast(BigDecimal('1.0'))).to be(1.0) }
    end
  end

  describe 'inet' do
    subject { described_class[:inet] }

    its(:cql_name) { is_expected.to eq(:inet) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.InetAddressType')
    end
  end

  describe 'int' do
    subject { described_class[:int] }

    its(:cql_name) { is_expected.to eq(:int) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.Int32Type')
    end

    describe '#cast' do
      specify { expect(subject.cast(1)).to be(1) }
      specify { expect(subject.cast('1')).to be(1) }
      specify { expect(subject.cast(1.0)).to be(1) }
      specify { expect(subject.cast(1.0.to_r)).to be(1) }
      specify { expect(subject.cast(BigDecimal('1.0'))).to be(1) }
    end
  end

  describe 'bigint' do
    subject { described_class[:bigint] }

    its(:cql_name) { is_expected.to eq(:bigint) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.LongType')
    end

    describe '#cast' do
      specify { expect(subject.cast(1)).to be(1) }
      specify { expect(subject.cast('1')).to be(1) }
      specify { expect(subject.cast(1.0)).to be(1) }
      specify { expect(subject.cast(1.0.to_r)).to be(1) }
      specify { expect(subject.cast(BigDecimal('1.0'))).to be(1) }
    end
  end

  describe 'text' do
    subject { described_class[:text] }

    its(:cql_name) { is_expected.to eq(:text) }
    its(:internal_name) { is_expected.to eq('org.apache.cassandra.db.marshal.UTF8Type') }
    it { is_expected.to eq(described_class[:varchar]) }

    describe '#cast' do
      specify { expect(subject.cast('cql')).to eq('cql') }
      specify { expect(subject.cast(1)).to eq('1') }
      specify { expect(subject.cast('cql').encoding.name).to eq('UTF-8') }

      specify do 
        expect(subject.cast('cql'.force_encoding('US-ASCII'))
        .encoding.name).to eq('UTF-8')
      end
    end
  end

  describe 'timestamp' do
    subject { described_class[:timestamp] }

    its(:cql_name) { is_expected.to eq(:timestamp) }
    its(:internal_name) { is_expected.to eq('org.apache.cassandra.db.marshal.DateType') }

    describe '#cast' do
      let(:now) { Time.at(Time.now.to_i) }

      specify { expect(subject.cast(now)).to eq(now) }
      specify { expect(subject.cast(now.to_i)).to eq(now) }
      specify { expect(subject.cast(now.to_s)).to eq(now) }
      specify { expect(subject.cast(now.to_datetime)).to eq(now) }
      specify { expect(subject.cast(now.to_date)).to eq(now.to_date.to_time) }
    end
  end

  describe 'date' do
    subject { described_class[:date] }

    its(:cql_name) { is_expected.to eq(:date) }
    its(:internal_name) { is_expected.to eq('org.apache.cassandra.db.marshal.DateType') }

    describe '#cast' do
      let(:today) { Date.today }

      specify { expect(subject.cast(today)).to eq(today) }
      specify { expect(subject.cast(today.to_s)).to eq(today) }
      specify { expect(subject.cast(today.to_datetime)).to eq(today) }
      specify { expect(subject.cast(today.to_time)).to eq(today) }
    end
  end

  describe 'timeuuid' do
    subject { described_class[:timeuuid] }

    its(:cql_name) { is_expected.to eq(:timeuuid) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.TimeUUIDType')
    end
  end

  describe 'uuid' do
    subject { described_class[:uuid] }

    its(:cql_name) { is_expected.to eq(:uuid) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.UUIDType')
    end

    describe '#cast' do
      let(:uuid) { Cequel.uuid }

      specify { expect(subject.cast(uuid)).to eq(uuid) }
      specify { expect(subject.cast(uuid.to_s)).to eq(uuid) }
      specify { expect(subject.cast(uuid.value)).to eq(uuid) }

      if defined? SimpleUUID::UUID
        specify do 
          expect(subject.cast(SimpleUUID::UUID.new(uuid.value)))
            .to eq(uuid)
        end
      end
    end
  end

  describe 'varint' do
    subject { described_class[:varint] }

    its(:cql_name) { is_expected.to eq(:varint) }

    its(:internal_name) do
      is_expected.to eq('org.apache.cassandra.db.marshal.IntegerType')
    end

    describe '#cast' do
      specify { expect(subject.cast(1)).to be(1) }
      specify { expect(subject.cast('1')).to be(1) }
      specify { expect(subject.cast(1.0)).to be(1) }
      specify { expect(subject.cast(1.0.to_r)).to be(1) }
      specify { expect(subject.cast(BigDecimal('1.0'))).to be(1) }
    end
  end

  describe '::quote' do
    [
      ["don't", "'don''t'"],
      ["don't".force_encoding('US-ASCII'), "'don''t'"],
      ["don't".force_encoding('ASCII-8BIT'), "'don''t'"],
      ["3dc49a6".force_encoding('ASCII-8BIT'), "0x3dc49a6"],
      [%w[one two], "'one','two'"],
      [1, '1'],
      [1.2, '1.2'],
      [true, 'true'],
      [false, 'false'],
      [Time.at(1_401_323_181, 381_000), '1401323181381'],
      [Time.at(1_401_323_181, 381_999), '1401323181382'],
      [Time.at(1_401_323_181, 381_000).in_time_zone, '1401323181381'],
      [Date.parse('2014-05-28'), "1401235200000"],
      [Time.at(1_401_323_181, 381_000).to_datetime, '1401323181381'],
      [Cequel.uuid("dbf51e0e-e6c7-11e3-be60-237d76548395"),
       "dbf51e0e-e6c7-11e3-be60-237d76548395"]
    ].each do |input, output|
      specify { expect(described_class.quote(input)).to eq(output) }
    end
  end

end
