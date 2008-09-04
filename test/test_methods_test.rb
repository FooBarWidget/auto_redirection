require File.dirname(__FILE__) + '/abstract_unit'
require File.dirname(__FILE__) + '/book_store'

class TestMethodsTest < ActionController::IntegrationTest
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
