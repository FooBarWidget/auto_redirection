# Copyright (c) 2008 Phusion
# http://www.phusion.nl/
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'uri'

module AutoRedirection

# This module allows one to unit test auto-redirections in Ruby on Rails
# integration tests. Include this module in your integration test class, and
# its methods will become available in the integration test.
#
# Furthermore, this module extends the behavior of some integration test
# methods, such as +get+ and +post+.
#
# Synposis:
#
#  require 'auto_redirection/testing'
#  
#  class SomeTest < ActionController::IntegrationTest
#     include AutoRedirection::Testing
#     
#     def test_something
#        ...
#     end
#  end
module Testing
protected
	# Performs a GET request, just like the normal +get+ method in integration
	# tests (ActionController::Integration::Session#get). The last request's
	# URI will be automatically passed as the "Referer" HTTP header.
	#
	#   get "/books/show/1"
	#   # "/books/show/1" is now recorded as the referer.
	#   
	#   get_with_referer "/books/show/2"
	#   puts @request.headers["Referer"]
	#   # => "/books/show/1"
	def get(path, parameters = nil, headers = nil)
		result = super(path, add_redirection_information(parameters),
			add_referer(headers))
		@_referer = path
		return result
	end
	
	# Performs a POST request, just like the normal +post+ method in integration
	# tests (ActionController::Integration::Session#post). The last request's
	# URI will be automatically passed as the "Referer" HTTP header.
	#
	# See +get_with_referer+ for an example.
	def post(path, parameters = nil, headers = nil)
		result = super(path, add_redirection_information(parameters),
			add_referer(headers))
		@_referer = path
		return result
	end
	
	# Performs a PUT request, just like the normal +get+ method in integration
	# tests (ActionController::Integration::Session#get). The last request's
	# URI will be automatically passed as the "Referer" HTTP header.
	#
	# See +get_with_referer+ for an example.
	def put(path, parameters = nil, headers = nil)
		result = super(path, add_redirection_information(parameters),
			add_referer(headers))
		@_referer = path
		return result
	end
	
	# Performs a DELETE request, just like the normal +delete+ method in integration
	# tests (ActionController::Integration::Session#delete). The last recorded
	# referer will be passed as the "Referer" HTTP header. After the request,
	# the current path will be recorded as the new referer.
	#
	# See +get_with_referer+ for an example.
	def delete(path, parameters = nil, headers = nil)
		result = super(path, add_redirection_information(parameters),
			add_referer(headers))
		@_referer = path
		return result
	end
	
	# Asserts that the redirection information that the last controller
	# action received is equal to +path+.
	#
	# If +parameters+ is not nil, then it will also assert that the
	# parameters in the redirection information is equal to +parameters+. (To
	# assert that the parameters are empty, pass an empty hash.)
	#
	# Example:
	#
	#   # User views a book.
	#   get('/books/show/1')
	#   
	#   # On that page, the user clicks on the 'Login' link.
	#   get('/login/login_form')
	#   # Assert that the login page knows that he came from /books/show/1
	#   assert_came_from('/books/show/1')
	#   
	#   # The user enters the wrong password and clicks on 'Submit'.
	#   post('/login/process_login', :username => 'foo', :password => 'wrong')
	#   # Assert that the login form page told 'process_login' that we came
	#   # from /books/show/1
	#   assert_came_from('/books/show/1')
	def assert_came_from(path, parameters = nil)
		info = @controller.send(:get_redirection_information)
		if info.nil?
			raise Test::Unit::AssertionFailedError, "No redirection information."
		end
		
		assert_equal path, info.path
		
		if parameters
			params = info.params.with_indifferent_access.dup
			params.delete(:controller)
			params.delete(:action)
			params.delete(:_redirection_information)
			assert_equal parameters.with_indifferent_access, params
		end
	end
	
	# Asserts that the last controller action tried to redirect the browser
	# to page using a non-GET request.
	#
	# +method+ is a Symbol which specifies the HTTP method, e.g. +:post+ or
	# +:delete+. +path+ is the path that the browser should be redirected to.
	# +parameters+ is the exepcted HTTP parameters.
	#
	# Do not use this method with normal redirections (e.g. redirections to
	# GET requests). Use +assert_redirected_to+ in that case.
	#
	#   # User posts a comment.
	#   post('/comments/create', :summary => 'hi')
	#   # But he isn't logged in, so he's redirected to the login page.
	#   assert_redirected_to '/login/login_form'
	#   
	#   # User logs in.
	#   post('/login/process_login', :password => 'secret')
	#   # The login controller instructs the browser to POST to
	#   # /comments/create with the original parameters. That is, we are
	#   # dealing with a non-GET redirection.
	#   assert_redirection_with_method(:post, '/comments/create', :summary => 'hi')
	#   
	#   # Follow this instruction, i.e. let us be redirected to
	#   # /comments/create.
	#   follow_redirection_with_method!
	#   
	#   # Comment has been posted.
	#   assert_not_equal 0, Comment.find(:all).size
	def assert_redirection_with_method(method, path, parameters = nil)
		result = parse_post_redirection_page
		assert_equal path, result[:path]
		if result[:method] != method
			raise Test::Unit::AssertionFailedError,
				"<#{method}> redirection expected, but " <<
				"<#{result[:method]}> redirection found."
		end
		if parameters
			assert_equal parameters.with_indifferent_access, result[:params]
		end
	end
	
	# If the last controller action wants to redirect the browser with a
	# non-GET request, then this method will follow this redirection. Otherwise,
	# this method will raise an assertion error.
	#
	# Do not use this method with normal redirections (e.g. redirections to
	# GET requests). Use +follow_redirect!+ in that case.
	#
	# See +assert_redirection_with_method+ for an example.
	def follow_redirection_with_method!
		result = parse_post_redirection_page
		params = result[:params].merge(:_redirection_information => result[:redirection_data])
		headers = { :HTTP_REFERER => @_referer }
		old_referer = @_referer
		case result[:method]
		when :post
			post(result[:path], params, headers)
		when :put
			put(result[:path], params, headers)
		when :delete
			delete(result[:path], params, headers)
		else
			raise Test::Unit::AssertionFailedError,
				"Unknown method '#{result[:method]}'."
		end
	end
	
	# Parse the last controller action's response and extract any redirection
	# information that the +pass_redirection_information+ view helper has
	# outputted. This information -- as the raw parameter string -- is
	# returned, and may be passed to any controller action (via HTTP
	# parameters) as redirection information.
	#
	# Raises an assertion error if there is no redirection information in the
	# response body.
	def get_redirection_information_from_form
		info = try_get_redirection_information_from_form
		if info.nil?
			raise Test::Unit::AssertionFailedError,
				"There is no redirection information inside the form."
		else
			return info
		end
	end

private
	def add_redirection_information(params)
		if params
			params = params.with_indifferent_access
		else
			params = HashWithIndifferentAccess.new
		end
		if !params.has_key?(:_redirection_information)
			info = try_get_redirection_information_from_form
			if info
				params[:_redirection_information] = info
			end
		end
		return params
	end
	
	def add_referer(headers)
		if headers
			headers = headers.with_indifferent_access
		else
			headers = HashWithIndifferentAccess.new
		end
		headers.reverse_merge!(:HTTP_REFERER => @_referer)
		return headers
	end
	
	def try_get_redirection_information_from_form
		if @response.nil?
			return nil
		end
		hidden_field = css_select("input[name='_redirection_information']").first
		if !hidden_field
			return nil
		end
		return hidden_field['value']
	end
	
	def parse_query_string(str)
		return ActionController::AbstractRequest.parse_query_parameters(str)
	end
	
	def parse_post_redirection_page
		assert_response :ok, 'Controller did not render a redirection page.'
		if css_select('#_auto_redirection_form').empty?
			raise Test::Unit::AssertionFailedError,
				'Controller did not render a redirection page.'
		end
		
		form = css_select('#_auto_redirection_form').first
		if !form
			raise Test::Unit::AssertionFailedError,
				'Controller did not render a redirection page.'
		end
		
		result = {}
		uri = URI.parse(CGI::unescapeHTML(form['action']))
		result[:path] = uri.path
		
		method_field = css_select("#_auto_redirection_form input[name='_method']").first
		if method_field
			result[:method] = method_field['value'].to_sym
		else
			result[:method] = :post
		end
		
		params = parse_query_string(uri.query || "")
		result[:params] = params.with_indifferent_access
		
		redirection_info_field = css_select("#_auto_redirection_form input[name='_redirection_information']").first
		if redirection_info_field
			result[:redirection_data] = redirection_info_field['value']
		end
		
		return result
	end
end

end # module AutoRedirection
