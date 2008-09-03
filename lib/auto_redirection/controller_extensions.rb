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
module AutoRedirection

module ControllerExtensions
protected
	# Saves redirection information into the flash, so that the next
	# controller action may use this information.
	#
	# +location+ may either be +:here+, or a String containing an URL.
	def save_redirection_information(location = :here)
		case location
		when :here
			parameters = params
			current_redirection_info = get_redirection_information
			if current_redirection_info
				parameters = params.merge(:_redirection_information =>
					current_redirection_info.marshal)
			else
				parameters = params
			end
			
			redirection_info_to_pass = ControllerRedirectionInformation.new(
				controller_path, action_name, parameters, request.method)
			flash[:_redirection_information] = redirection_info_to_pass.marshal(true, false)
			logger.debug("Auto-Redirection: saving redirection information " <<
				"for: #{controller_path}/#{action_name} (#{request.method})")
		when String
			info = UrlRedirectionInformation.new(location)
			flash[:_redirection_information] = info.marshal(true, false)
			logger.debug("Auto-Redirection: saving redirection information " <<
				"for: #{location}")
		else
			raise ArgumentError, "Unknown location #{location.inspect}."
		end
	end
	
	# Returns auto-redirection information for the current request.
	def current_request
		@_current_request ||= begin
			info = {
				'controller' => controller_path,
				'action' => action_name,
				'method' => request.method,
				'params' => params
			}
			Encryption.encrypt(Marshal.dump(info))
		end
	end

	# The current request may contain redirection information.
	# If auto-redirection information is given, then this method will redirect
	# the HTTP client to that location (by calling +redirect_to+) and return true.
	# Otherwise, it will return false.
	#
	# Redirection information is obtained from the following sources, in
	# the specified order:
	# 1. The <tt>_redirection_information</tt> request parameter.
	# 2. The <tt>_redirection_information</tt> flash entry.
	# 3. The "Referer" HTTP header.
	def attempt_auto_redirect
		info = get_redirection_information
		if info.nil?
			return false
		end
		
		# The page where we're redirecting to might have redirection information
		# as well. So we save that information to flash[:auto_redirect_to] to
		# allow nested auto-redirections.
		if info.method == :get
			if info.is_a?(UrlRedirectionInformation)
				logger.debug("Auto-Redirection: redirect to URL: #{info.url}")
				redirect_to info.url
			else
				args = info.params.merge(
					:controller => info.controller,
					:action => info.action
				)
				logger.debug("Auto-Redirection: redirecting to: " <<
					"#{info.controller}/#{info.action} (get), " <<
					"parameters: #{info.params.inspect}")
				redirect_to args
			end
		else
			@redirection_information = info
			@form_action = info.params.merge(
				'controller' => info.controller,
				'action'     => info.action
			)
			
			# We want to put nested redirection information a hidden field
			# so that the data can be posted in the POST body instead of
			# the HTTP request query string.
			@nested_redirection_information = @form_action['_redirection_information']
			@form_action.delete('_redirection_information')
			
			logger.debug("Auto-Redirection: redirecting to: " <<
				"#{info.controller}/#{info.action} (#{info.method}), " <<
				"parameters: #{info.params.inspect}")
			render :inline => TEMPLATE_FOR_POST_REDIRECTION, :layout => false
		end
		return true
	end
	
	# Try to redirect the browser by calling +attempt_auto_redirect+. If that
	# method returns false, then the browser will be redirected to +root_path+
	# instead.
	def auto_redirect
		if !attempt_auto_redirect
			redirect_to root_path
		end
	end

private
	# Retrieve the redirection information that has been passed to the current
	# controller action. Returns nil if no redirection information has been passed.
	def get_redirection_information
		if !@_redirection_information_given
			if params.has_key?(:_redirection_information)
				info = RedirectionInformation.load(params[:_redirection_information])
			elsif flash.has_key?(:_redirection_information)
				info = RedirectionInformation.load(flash[:_redirection_information], true, false)
			elsif request.headers["Referer"]
				info = UrlRedirectionInformation.new(request.headers["Referer"])
			else
				info = nil
			end
			@_redirection_information_given = true
			@_redirection_information = info
		end
		return @_redirection_information
	end
end

end # module AutoRedirections
