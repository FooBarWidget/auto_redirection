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

module ViewHelpers
	# Returns a hidden field tag, which contains information about where the
	# form action should redirect the browser to when it's done.
	#
	# The page to redirect to is retrieved from the redirection information
	# that the current controller action has received. If there is no such
	# information, then this method will return +nil+.
	def pass_redirection_information
		return render_redirection_information(get_redirection_information)
	end
	
	def auto_redirect_to(location, params = {})
		# TODO: merge this with 'auto_redirect_to' in ControllerExtensions.
		case location
		when :here
			info = {
				'controller' => controller.controller_path,
				'action' => controller.action_name,
				'method' => controller.request.method,
				'params' => controller.params.merge(params)
			}
			logger.debug("Auto-Redirection: saving redirection information " <<
				"for: #{controller.controller_path}/#{controller.action_name}" <<
				" (#{request.method}), parameters: #{info['params'].inspect}")
		else
			raise ArgumentError, "Unknown location '#{location}'."
		end
		return render_redirection_information(info)
	end

private
	def get_redirection_information
		return controller.send(:get_redirection_information)
	end
	
	def render_redirection_information(info)
		if info
			RAILS_DEFAULT_LOGGER.info(info.inspect)
			value = h(info.marshal)
			html = %Q{<input type="hidden" name="_redirection_information" value="#{value}"}
			if AutoRedirection.xhtml
				html << " /"
			end
			html << ">"
			if AutoRedirection.debug?
				# Value intentionally not escaped.
				html << "\n<!-- #{info.inspect} -->"
			end
			return html
		else
			return nil
		end
	end
end

end # module AutoRedirection
