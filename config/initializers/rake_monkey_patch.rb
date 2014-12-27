# default size 65536
Rack::Utils.key_space_limit = 6553600 if Rack::Utils.respond_to?("key_space_limit=")
