require 'sinatra/base'

class PrismServer < Sinatra::Base
  get '/' do
    'Hello world!'
  end

  get '/:sha' do
    content_type 'text/plain'
    sha = params[:sha]
    res = Prism.symbolize_crash_report_from_sha(sha)
    return "unable to fetch gist id=#{sha}" unless res
    res
  end

end

def Prism.serve(options={})
  puts "updating archive..."
  update_archive()
  PrismServer.set :port, options.port if options.port
  PrismServer.run!
end