module AutoRedirection

class RedirectionInformation
	def self.load(data, encrypted = true, ascii7 = true)
		if encrypted
			data = Encryption.decrypt(data, ascii7)
		end
		info = Marshal.load(data)
		if info[:url]
			return UrlRedirectionInformation.new(info[:url])
		else
			return ControllerRedirectionInformation.new(
				info[:controller],
				info[:action],
				info[:params],
				info[:method])
		end
	end
	
	def marshal(encrypt = true, ascii7 = true)
		data = yield
		if encrypt
			data = Encryption.encrypt(data, ascii7)
		end
		return data
	end
end

class UrlRedirectionInformation < RedirectionInformation
	attr_accessor :url
	
	def initialize(url = nil)
		@url = url
	end
	
	def method
		return :get
	end
	
	def marshal(encrypt = true, ascii7 = true)
		super do
			Marshal.dump({
				:method => :get,
				:url => url
			})
		end
	end
	
	def ==(other)
		return other.is_a?(UrlRedirectionInformation) && other.url == url
	end
end

class ControllerRedirectionInformation < RedirectionInformation
	attr_accessor :controller, :action, :params, :method
	
	def initialize(controller_path, action_name, params = {}, method = :get)
		@controller = controller_path
		@action = action_name
		@params = params || {}
		@method = method || :get
	end
	
	def marshal(encrypt = true, ascii7 = true)
		super do
			Marshal.dump({
				:method => @method,
				:controller => @controller,
				:action => @action,
				:params => @params
			})
		end
	end
	
	def ==(other)
		return other.is_a?(ControllerRedirectionInformation) &&
		       other.controller == controller &&
		       other.action     == action &&
		       other.params     == params &&
		       other.method     == method
	end
end

end # module AutoRedirection
