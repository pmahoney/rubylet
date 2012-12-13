require 'spec_helper'
require 'rubylet/mem_file_io'

module Rubylet

  describe MemFileIO do
    
    it 'writes data with puts' do
      @io = MemFileIO.new
      @io.puts('hello')
      @io.rewind
      @io.read.must_equal "hello#{$/}"
    end

    it 'writes data with write' do
      @io = MemFileIO.new
      @io.write('hello')
      @io.rewind
      @io.read.must_equal 'hello'
    end

    it 'allows multiple rewind' do
      @io = MemFileIO.new

      @io.write('hello')
      @io.rewind
      @io.read.must_equal 'hello'

      @io.write('hello')
      @io.rewind
      @io.read.must_equal 'hellohello'
    end

    it 'overwrites? (FIXME: is this correct?)' do
      @io = MemFileIO.new

      @io.write('hello')
      @io.rewind
      @io.read.must_equal 'hello'

      @io.rewind
      @io.write('***')
      @io.rewind
      @io.read.must_equal '***lo'
    end

    it 'switches to backing file' do
      @io = MemFileIO.new(4)
      @io.write('1234')
      @io.write('5678')
      @io.rewind
      @io.read.must_equal '12345678'
    end

    it 'returns nil on EOF' do
      @io = MemFileIO.new
      @io.read
      @io.read(1).must_equal nil
    end

    it 'returns empty string on EOF' do
      @io = MemFileIO.new
      @io.read
      @io.read.must_equal ''
    end
  end

end
