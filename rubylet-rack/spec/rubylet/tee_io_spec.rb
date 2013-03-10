require 'spec_helper'
require 'rubylet/tee_io'
require 'stringio'

module Rubylet

  describe TeeIO do

    DATA = "some data\nwith newlines\nanother line"

    before :each do
      @io = StringIO.new
      @io.write(DATA)
      @io.rewind

      @out = StringIO.new

      @tee = TeeIO.new(@io, @out)
    end
    
    it 'copies data on read' do
      @tee.read
      @out.rewind
      @out.read.must_equal DATA
    end

    describe '#gets' do
      it 'copies data on gets' do
        @tee.gets
        @out.rewind
        @out.read.must_equal "some data\n"
      end

      it 'returns nil on EOF' do
        @tee.read
        @tee.gets.must_equal nil
      end
    end

    it 'copies data on each' do
      @tee.each {}
      @out.rewind
      @out.read.must_equal DATA
    end

    it 'copies data byte by byte' do
      @tee.read(1)
      @tee.read(1)
      @out.rewind
      @out.read.must_equal 'so'
    end

    it 'reads data into a given buffer' do
      buf = String.new
      ret = @tee.read nil, buf

      ret.object_id.must_equal buf.object_id

      buf.must_equal DATA
      @out.rewind
      @out.read.must_equal DATA
    end

    it 'returns nil on EOF' do
      @tee.read
      @tee.read(1).must_equal nil
    end

    it 'returns empty string on EOF' do
      @tee.read
      @tee.read.must_equal ''
    end
  end

end
