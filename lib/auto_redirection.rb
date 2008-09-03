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

# This library allows one to easily implement so-called "auto-redirections".
#
# Consider the following use cases:
# 1. A person clicks on the 'Login' link from an arbitrary page. After logging in,
#    he is redirected back to the page where he originally clicked on 'Login'.
# 2. A person posts a comment, but posting comments requires him to be logged in.
#    So he is redirected to the login page, and after a successful login, the
#    comment that he wanted to post before is now automatically posted. He is also
#    redirected back to the page where the form was.
#
# In all of these use cases, the visitor is automatically redirected back to a
# certain place on the website, hence the name "auto-redirections".
#
# Use case 2 is especially interesting. The comment creation action is typically
# a POST-only action, so the auto-redirecting with POST instead of GET must also
# be possible.
#
# To implement these use cases, one must pass some information to the next
# controller, so that it knows where to redirect the user to. auto_redirection
# makes it easy to do this.
#
#
# == Basic usage
#
# Let's consider use case 1. Suppose that you have:
#
# - a +BooksController+, and the visitor is only allowed to view a book if he's
#   logged in.
# - a +LoginController+, which handles logins.
#
# When an anonymous visitor visits '/books/1', we want BooksController#show to
# redirect him to the login page. After successfull login, we want
# LoginController to redirect him back to '/books/1'.
#
# What we must do is to somehow tell LoginController that the visitor came from
# '/books/1'. This example shows you how. Let's consider BooksController:
#
#   class BooksController < ApplicationController
#      def show
#         if logged_in?
#            @book = Book.find(params[:id])
#            render(:action => 'show')
#         else
#            # User must be logged in to view this book.
#            redirect_to('/login/login_form')
#         end
#      end
#   end
#
# Let's also consider LoginController and how it should be modified. When a
# login is successful, instead of calling +redirect_to+ on a hardcoded location,
# call +auto_redirect+:
#
#   class LoginController < ApplicationController
#      def process_login
#         if User.authenticate(params[:username], params[:password])
#            # Login successful! Redirect user back to where he came from.
#            flash[:message] = "You are now logged in."
#            
#            # redirect_to('/books')  # <--- commented out!
#            auto_redirect            # <--- replaced with this!
#         else
#            flash[:message] = "Wrong username or password!"
#            render(:action => 'login_form')
#         end
#      end
#   end
#
# +auto_redirect+ will take care of redirecting the browser back to where it was,
# before the login page was accessed. But how does it know where to redirect to?
# The answer: almost every browser sends the "Referer" HTTP header, which tells the
# web server where the browser was. +auto_redirect+ makes use of that information.
#
# <b>Note:</b> Unlike <tt>redirect_to :back</tt>, +auto_redirect+ will redirect
# the browser to +root_path+ if there's no redirection information.
#
# === Passing current redirection information via a form
#
# There is a problem however. Suppose that the user typed in the wrong password and
# is redirected back to the login page once again. Now the browser will send the URL
# of the login page as the referer! That's obviously undesirable: after login,
# we want to redirect the browser back to where it was *before* the login page was
# accessed.
#
# What we're supposed to do now is to tell LoginController what the original
# Referer was, before the login page was accessed. To do this, we insert a
# little piece of information into the login page's form:
#
#   <% form_tag('/login/process_login') do %>
#      <%= pass_redirection_information %>  <!-- Added! -->
#      
#      Username: <input type="text" name="username"><br>
#      Password: <input type="password" name="password"><br>
#      <input type="submit" value="Login!">
#   <% end %>
#
# The +pass_redirection_information+ view helper saves the initial referer into
# a hidden field called '_redirection_information'. +auto_redirect+ will use that
# information instead of the "Referer" header whenever possible.
#
# That's it, we're done. :) So in summary, one must:
# - use +auto_redirect+, which redirect the user back to where he came from,
#   according to any redirection information that has been received.
# - in the view, pass the current redirection information to the next controller
#   action by using the +pass_redirection_information+ view helper.
#
#
# == Handling non-GET requests
#
# Use case 2 is a bit different. We can't rely on the "Referer" HTTP header, because
# upon redirecting back, we want the original POST request parameters to be sent as
# well. POST parameters are not included in the "Referer" HTTP header.
#
# Suppose that you've changed your LoginController and login view template, as
# described in 'Basic Usage'. And suppose you also have a CommentsController,
# which requires the user to be logged in before he can post a comment.
#
# What we must do now is to tell LoginController not only that the visitor came
# from CommentsController#create, but also what its HTTP method and POST
# parameters were. To do this, we must use the +save_redirection_information+
# method, which saves this information into a flash entry called
# "_redirection_information", which is another place that the auto_redirection
# library looks at for retrieving redirection (in addition to the "Referer" HTTP
# header and the "_redirection_information" HTTP parameter).
#
#   class CommentsController < ApplicationController
#      def create
#         if logged_in?
#            comment = Comment.create!(params[:comment])
#            redirect_to(comment)
#         else
#            # Tell LoginController that we came from CommentsController#create,
#            # and what our request parameters were.
#            save_redirection_information
#            redirect_to('/login/login_form')
#         end
#      end
#   end
#
# Now that LoginController's +auto_redirect+ call knows the correct redirection
# information, it will take care of the rest.
#
# === Nested redirects
#
# Suppose that there are two places on your website that have a comments form:
# '/books/(id)' and '/reviews/(id)'. And the comments form currently looks like
# this:
#
#   <% form_for(@comment) do |f| %>
#      <%= f.text_area :contents %>
#      <%= submit_tag 'Post comment' %>
#   <% end %>
#
# When a visitor posts a comment via CommentsController#create, after a login
# he will be redirected back to CommentsController#create. But we also want
# CommentsController#create to redirect back to '/books/(id)' or '/reviews/(id)',
# depending on where the visitor came from. In other words, we want to be able
# to *nest* redirection information.
#
# Right now, CommentsController will always redirect to '/comments/id)' after
# having created a comments. So we change it a little:
#
#   class CommentsController < ApplicationController
#      def create
#         if logged_in?
#            comment = Comment.create!(params[:comment])
#            if !attempt_auto_redirect    # <-- changed!
#               redirect_to(comment)      # <-- changed!
#            end                          # <-- changed!
#         else
#            # Tell LoginController that we came from CommentsController#create,
#            # and what our request parameters were.
#            save_redirection_information
#            redirect_to('/login/login_form')
#         end
#      end
#   end
#
# Now, CommentsController will redirect using whatever auto-redirection information
# it has received. If no auto-redirection information is given (i.e.
# +attempt_auto_redirect+ returns false) then it returns the visitor to
# '/comments/(id)'.
#
#
# === Saving POST auto-redirection information without a session
#
# The flash is not available if sessions are disabled. In that case, you have to pass
# auto-redirection information via a GET parameter, like this:
#
#   redirect_to('/login/login_form', :auto_redirect_to => current_request)
#
# The +current_request+ method returns auto-redirection information for the
# current request.
#
# == Security
#
# Auto-redirection information is encrypted, so it cannot be read or tampered with
# by third parties. Be sure to set a custom encryption key instead of leaving
# the key at the default value. For example, put this in your environment.rb:
#
#   AutoRedirection.encryption_key = "my secret key"
#
# <b>Tip:</b> use 'rake secret' to generate a random key.
module AutoRedirection
	# The key to use for encrypting auto-redirection information.
	mattr_accessor :encryption_key
	@@encryption_key = "e1cd3bf04d0a24b2a9760d95221c3dee"
	
	# Whether this library's view helper methods should output XHTML (instead
	# of regular HTML). Default: true.
	mattr_accessor :xhtml
	@@xhtml = true
	
	# Whether to enable debugging. Default: true.
	mattr_accessor :debug
	class << self
		alias debug? debug
	end
	@@debug = true
	
	# A view template for redirecting the browser back to a place, while
	# sending a POST request.
	TEMPLATE_FOR_POST_REDIRECTION = %q{
		<% form_tag(@form_action, { :method => @redirection_information.method, :id => 'form' }) do %>
			<div class="nested_redirection_information">
			<%= hidden_field_tag('_redirection_information', @nested_redirection_information) if @nested_redirection_information %>
			</div>
			<noscript>
				<input type="submit" value="Click here to continue." />
			</noscript>
			<div id="message" style="display: none">
				<h2>Your request is being processed...</h2>
				<input type="submit" value="Click here if you are not redirected within 5 seconds." />
			</div>
		<% end %>
		<script type="text/javascript">
		//<![CDATA[
			document.getElementById('form').submit();
			setTimeout(function() {
				//# If server doesn't respond within 1 second, then
				//# display a wait message.
				document.getElementById('message').style.display = 'block';
			}, 1000);
		// ]]>
		</script>
	}
end

require 'auto_redirection/redirection_information'
require 'auto_redirection/controller_extensions'
require 'auto_redirection/view_helpers'
require 'auto_redirection/marshal_extensions'
require 'auto_redirection/encryption'

ActionController::Base.send(:include, AutoRedirection::ControllerExtensions)
ActionView::Base.send(:include, AutoRedirection::ViewHelpers)
ActionController::UploadedFile.send(:include, AutoRedirection::MarshalExtensions)

