require File.dirname(__FILE__) + '/abstract_unit'
require File.dirname(__FILE__) + '/book_store'
require 'uri'

module AutoRedirection
module Testing
protected
	def get(path, parameters = nil, headers = nil)
		@_referer = path
		super(path, parameters, headers)
	end
	
	def post(path, parameters = nil, headers = nil)
		@_referer = path
		super(path, parameters, headers)
	end
	
	def get_with_referer(path, parameters = nil, headers = nil)
		if headers
			headers = headers.with_indifferent_access
		else
			headers = HashWithIndifferentAccess.new
		end
		headers.reverse_merge!(:HTTP_REFERER => @_referer)
		get(path, parameters, headers)
	end
	
	def post_with_referer(path, parameters = nil, headers = nil)
		if headers
			headers = headers.with_indifferent_access
		else
			headers = HashWithIndifferentAccess.new
		end
		headers.reverse_merge!(:HTTP_REFERER => @_referer)
		post(path, parameters, headers)
	end
	
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
	
	def get_redirection_information_from_form
		hidden_field = css_select("input[name='_redirection_information']").first
		if !hidden_field
			raise Test::Unit::AssertionFailedError,
				"There is no redirection information inside the form."
		end
		return hidden_field['value']
	end
	
	def follow_redirection_with_method!
		result = parse_post_redirection_page
		params = result[:params].merge(:_redirection_information => result[:redirection_data])
		case result[:method]
		when :post
			post(result[:path], params)
		when :put
			put(result[:path], params)
		when :delete
			delete(result[:path], params)
		else
			raise Test::Unit::AssertionFailedError,
				"Unknown method '#{result[:method]}'."
		end
	end

private
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
end

class TestMethodsTest < ActionController::IntegrationTest
	include AutoRedirection
	include TestHelpers
	include AutoRedirection::Testing
	
	test "scenario with nested redirects" do
		# Visitor is at a book page.
		get "/books/show/1"
		assert_response :ok
		
		# He posts a comment using the form on that page.
		post_with_referer("/comments/create", { :summary => "hi" })
		# And gets redirected to the login page.
		assert_redirected_to '/login/login_form'
		
		# He loads the login page.
		get_with_referer('/login/login_form', nil)
		assert_response :ok
		# The login page knows that he came from /comments/create.
		assert_came_from('/comments/create', { :summary => "hi" })
		
		# He logs in but entered the wrong password.
		post_with_referer("/login/process_login", {
			:password => 'wrong',
			:_redirection_information => get_redirection_information_from_form
		})
		# So the login page is redisplayed.
		assert_response :ok
		# The login page still knows that he came from /comments/create.
		assert_came_from('/comments/create', { :summary => "hi" })

		# He logs in, this time with the correct password.
		post_with_referer("/login/process_login", {
			:password => 'secret',
			:_redirection_information => get_redirection_information_from_form
		})
		assert_redirection_with_method(:post, '/comments/create', :summary => 'hi')
		
		# /comments/create creates the comment and redirects us back to
		# /books/show/1.
		follow_redirection_with_method!
		assert_redirected_to '/books/show/1'
	end
end
