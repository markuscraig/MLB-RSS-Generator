require 'sinatra'
require 'net/http'
require 'uri'
require 'rexml/document'

# game info class
class Game
	attr_accessor :id, :status, :start_time, :delay_reason, :teams
	
	def initialize
		@teams = Array.new(2)
	end
end

# team info class
class Team
	attr_accessor :name, :runs, :hits, :errors
	
	def initialize
	end
end

# mlb agent class
class MlbAgent
	attr_accessor :url, :xml_data, :xml_doc, :games
	
	def initialize
		# build the mlb stats url for today
		build_url()
		
		# fetch the mlb xml data
		@xml_data = fetch_xml_data()
		
		# parse the data into an xml document
		@xml_doc = parse_xml(@xml_data)
	end
	
	def build_url
		url_year = 'year_2011'
		url_month = 'month_09'
		url_day = 'day_03'
		@url = "http://gd2.mlb.com/components/game/mlb/#{url_year}/#{url_month}/#{url_day}/scoreboard.xml"
		puts "MLB URL = #{@url}"
	end
	
	def fetch_xml_data
		# get the mlb xml data
		Net::HTTP.get_response(URI.parse(@url)).body
	end
	
	def parse_xml(xml)
		# initialize the array of games
		@games = []
		
		# parse the xml into a document
		@xml_doc = REXML::Document.new(xml)

		# get the game info for the games that have finished
		parse_game_xml(@xml_doc, 'scoreboard/go_game', games)

		# get the game info for the games that are in-progress
		parse_game_xml(@xml_doc, 'scoreboard/ig_game', games)

		# get the game info for the games that are upcoming
		parse_game_xml(@xml_doc, 'scoreboard/sg_game', games)

		# return the xml document
		@xml_doc
	end
	
	def parse_game_xml(doc, game_path, games)
		# spin through each of the game elements
		doc.elements.each(game_path) do |game_element|
			# create a new game object
			game = Game.new
			
			# populate the game object
			game_attributes = game_element.elements['game'].attributes
			game.id = game_attributes['id']
			game.status = game_attributes['status']
			game.start_time = game_attributes['start_time']
			game.delay_reason = game_attributes['delay_reason']
			game_element.elements.each_with_index('team') do |team_element, index|
				if (index < 2)
					team = game.teams[index] = Team.new
					team.name = team_element.attributes['name']
					team.runs = team_element.elements['gameteam'].attributes['R']
					team.hits = team_element.elements['gameteam'].attributes['H']
					team.errors = team_element.elements['gameteam'].attributes['E']
				end
			end
			
			# add the game object to the game array
			games << game
		end
	end
end

class GameExporter
	attr_accessor :rss_version, :rss_dtd
	attr_accessor :title, :title_link, :title_description
	attr_accessor :image_title, :image_url, :image_link
	attr_accessor :web_master
	
	def initialize
		@rss_version = '0.91'
		@rss_dtd = 'http://my.netscape.com/publish/formats/rss-0.91.dtd'
		@title = "RSS Title"
		@title_link = "http://cisco.com"
		@title_description = "RSS Description"
		@image_title = ""
		@image_url = ""
		@image_link = ""
		@web_master = ""
	end
	
	def rss(games)
		# create the rss header
		rss = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n\n" +
			"<!DOCTYPE rss PUBLIC \"-//Netscape Communications//DTD RSS #{@rss_version}//EN\"\n" +
			" \"#{@rss_dtd}\">\n\n" +
			"<rss version=\"#{@rss_version}\">\n\n" + 
			"<channel>\n" +
			"<title>#{@title}</title>\n" +
			"<link>#{@title_link}</link>\n" +
			"<description>#{@title_description}</description>\n" +
			"<language>en-us</language>\n" +
			"<image>\n" +
			" <title>#{@image_title}</title>\n" +
			" <url>#{@image_url}</url>\n" +
			" <link>#{@image_link}</link>\n" +
			"</image>\n" +
			"<webMaster>#{@web_master}</webMaster>\n"
		
		# spin through each game in the given array
		games.each do |game|
			# get the game's status
			status = game.status
			
			# create the rss title based on the game state
			rss_title = ''
			if ((status == "PRE_GAME") || (status == "IMMEDIATE_PREGAME"))
				rss_title = game.teams[0].name + " vs " + game.teams[1].name +
					"  (Starts " + game.start_time + ")";
			elsif ((status == "FINAL") || (status == "GAME_OVER"))
				rss_title = game.teams[0].name + " " + game.teams[0].runs +
					game.teams[1].name + " " + game.teams[1].runs +
					"  (FINAL)";
			elsif ((status == "DELAYED") || (status == "OTHER"))
				rss_title = game.teams[0].name + " vs " + game.teams[1].name +
                "  (" + game.delay_reason + ")"
			elsif (status == "IN_PROGRESS")
        #
        # NOTE: The inning information is *only* available
        #       when the game's status is set to 'IN_PROGRESS'.
        #
				
			else
			end
			
			# add the rss game entry
			rss = rss + "<item><title>" + rss_title + "</title></item>\n"
		end

		# add the rss footer
		rss = rss + "</channel></rss>"
	end
end

get '/mlb/stats/game_scores' do
	# create an mlb agent
	mlb_agent = MlbAgent.new
	
	# get the array of games
	games = mlb_agent.games
	
	puts "Number of games = #{games.length}"
	games.each do |game|
		puts "Game ID = #{game.id}"
		puts "Game status = #{game.status}"
		puts "Game start time = #{game.start_time}"
		puts "Team 1 = #{game.teams[0].name}"
		puts "Team 1 = #{game.teams[0].runs}"
		puts "Team 1 = #{game.teams[0].hits}"
		puts "Team 1 = #{game.teams[0].errors}"
		puts "Team 2 = #{game.teams[1].name}"
		puts "Team 2 = #{game.teams[1].runs}"
		puts "Team 2 = #{game.teams[1].hits}"
		puts "Team 2 = #{game.teams[1].errors}"
	end
	
	# create the game exporter
	exporter = GameExporter.new()
	exporter.title = 'MLBAM Live Daily Scores'
	exporter.title_link = 'http://pressbox.mlb.com'
	exporter.title_description = 'MLBAM Live Daily Scores'
	exporter.image_title = 'MLB Live Scores'
	exporter.image_url = 'http://www.mpiii.com/scores/mlb.gif'
	exporter.image_link = 'http://www.mlb.com'
	exporter.web_master = 'info@mlb.com'
	
	# export the games as rss
	rss = exporter.rss(games)
	
	# render the game rss in the response
	rss
end
