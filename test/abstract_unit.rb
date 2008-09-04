$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
require 'rubygems'
require 'stringio'
require 'test/unit'

gem 'rails', '~> 2.1.0'
require 'action_controller'
require 'action_controller/cgi_ext'
require 'action_controller/test_process'
require 'action_controller/integration'
require 'action_view/test_case'

require 'auto_redirection'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

RAILS_DEFAULT_LOGGER = Logger.new(STDOUT)
RAILS_DEFAULT_LOGGER.level = Logger::WARN
ActionController::Base.session_store = :memory_store
ActionController::Base.logger = RAILS_DEFAULT_LOGGER
ActionController::Routing::Routes.draw do |map|
	map.connect 'test/:action',  :controller => 'test'
	map.connect 'users/:action', :controller => 'users'
	
	map.connect 'books/:action/:id', :controller => 'books'
	map.connect 'comments/:action',  :controller => 'comments'
	map.connect 'login/:action',     :controller => 'login'
end

class Test::Unit::TestCase
	def self.test(name, &block)
		@@test_counts ||= {}
		@@test_counts[self.class.to_s] ||= 0
		@@test_counts[self.class.to_s] += 1
		test_name = sprintf("test %03d: %s", @@test_counts[self.class.to_s], name.squish).to_sym
		defined = instance_method(test_name) rescue false
		raise "#{test_name} is already defined in #{self}" if defined
		define_method(test_name, &block)
	end
end

module TestHelpers
private
	def form_action
		return CGI.unescapeHTML(css_select("#_auto_redirection_form").first['action'])
	end
	
	def parse_form_action
		uri = URI.parse(form_action)
		return [uri.path, CGI.parse(uri.query || "")]
	end
	
	def input_value(css_rule = "input")
		return CGI.unescapeHTML(css_select(css_rule).first['value'])
	end
end
