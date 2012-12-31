require 'spec_helper'
require 'rubylet/war_task'

module Rubylet
  JAVAEE_SCHEMA = 'http://java.sun.com/xml/ns/javaee/web-app_3_0.xsd'

  describe WarTask do

    before :each do
      @task = WarTask.new
    end
    
    it 'generates web.xml' do
      xml = @task.webapp_descriptor
      xml.must_validate JAVAEE_SCHEMA
    end

    it 'generates glassfish-web.xml' do
      @task.glassfish_descriptor
      
    end

    it 'generates jetty-web.xml' do
      @task.jetty_descriptor
    end

    it 'adds servlet descriptors' do
      @task.compile_mode = 'JIT'
      @task.static_file_filter
      @task.rubylet do |s|
        s.name = 'myname'
      end
      @task.rubylet do |s|
        s.name = 'MyOtherServlet'
      end
      xml = @task.webapp_descriptor

      xml.must_validate JAVAEE_SCHEMA

      # puts xml
      xml.must_match %r{<servlet-name>myname</servlet-name>}
      xml.must_match %r{rubylet.RestartableServlet</servlet-class>}
    end

    # it 'generate war' do
    #   Rake::Task['war'].invoke
    # end

    # it 'runs maven' do
    #   @task.mvn('--version')
    # end

  end
end
