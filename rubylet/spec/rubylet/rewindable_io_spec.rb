require 'spec_helper'
require 'rubylet/rewindable_io'
require 'stringio'

module Rubylet

  describe RewindableIO do
    
    data = "some data\nwith newlines\nanother line"

    before :each do
      @io = StringIO.new
      @io.write(data)
      @io.rewind

      @reio = RewindableIO.new(@io)
    end

    it 'rewinds' do
      @reio.read.must_equal data
      @reio.rewind
      @reio.read.must_equal data
    end

    it 'rewinds with file spill over' do
      expected = ''
      10.times do
        @io.write(data)
        expected << data
      end
      @io.rewind

      @reio = RewindableIO.new(@io, 32)
      @reio.read.must_equal expected
      @reio.rewind
      @reio.read.must_equal expected
    end
  end
end
