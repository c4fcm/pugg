require 'date'
require 'hpricot'
require 'open-uri'
require 'pp'
require 'json'
require './utilities/guardian/couch.rb'

error_counter = 0

baseurls = {"telegraph"=>"http://www.telegraph.co.uk", "dailymail"=>"http://www.dailymail.co.uk", "guardian"=>""}
url_key = {"telegraph"=>"url", "dailymail"=>"url", "guardian"=> "webUrl"}

server = Couch::Server.new("localhost", "5984")

index_data = JSON.parse(server.get("/#{ARGV[0]}/_all_docs").response.body)

index_data["rows"].each do |row|
  index = row["id"]
  article = JSON.parse(server.get("/#{ARGV[0]}/#{index}").response.body)
  if (article.has_key? "sharedata" and !article["sharedata"].nil? and 
     article["sharedata"].has_key? "total" and article["sharedata"]["total"]!=0) or
     !article.has_key?(url_key[ARGV[0]])
    print "o"
    next  
  end
  basepath = ""
  basepath = baseurls[ARGV[0]] if(!article[url_key[ARGV[0]]].match(/http/))
  url = "http://#{ARGV[1]}/?q=" + basepath + article[url_key[ARGV[0]]]

  begin
    sharedata = JSON.parse(URI.parse(url).read)
  rescue  Exception => e
    print "x"
    sleep(2)
    if e.message=="Timeout::Error"
      error_counter += 1
      redo if error_counter <= 3
    else
      error_counter = 0
      next
    end
  end
  print "."
  article["sharedata"] = sharedata

  server.put("/#{ARGV[0]}/#{index}", article.to_json)

  error_counter = 0
  sleep(1.0/8.0)
end
