require_relative 'spec_helper'

describe Cequel::Uuids do
  describe '#uuid' do
    specify { Cequel.uuid.is_a?(Cassandra::TimeUuid) }
    specify { Cequel.uuid != Cequel.uuid } # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands

    specify do 
      time = Time.now
      Cequel.uuid(time).to_time == time
    end

    specify do 
      time = DateTime.now
      Cequel.uuid(time).to_time == time.to_time
    end

    specify do 
      time = Time.zone.now
      Cequel.uuid(time).to_time == time.to_time
    end

    specify do 
      val = Cequel.uuid.value
      Cequel.uuid(val).value == val
    end

    specify do 
      str = Cequel.uuid.to_s
      Cequel.uuid(str).to_s == str
    end
  end

  describe '#uuid?' do
    specify { Cequel.uuid?(Cequel.uuid) }
    specify { !Cequel.uuid?(Cequel.uuid.to_s) }

    if defined? SimpleUUID::UUID
      specify { !Cequel.uuid?(SimpleUUID::UUID.new) }
    end
  end
end
