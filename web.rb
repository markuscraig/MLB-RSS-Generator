require 'sinatra'
require 'net/http'
require 'uri'
require 'rexml/document'

#
# Handle the "/mlb/stats/game_scores" url
#
get '/mlb/stats/game_scores' do

	# if a date was given in the query string parameters
	mlb_date = nil;
	if (params[:year] && params[:month] && params[:day])
		# use the custom date for fetching mlb data
		mlb_date = Time.new(params[:year], params[:month], params[:day])
	else
		mlb_date = Time.now
	end
	
	# create an mlb agent
	mlb_agent = MlbAgent.new(mlb_date)
	
	# get the array of games
	games = mlb_agent.games
	
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

#
# Game info class
#
class Game
	attr_accessor :id, :status, :start_time, :delay_reason, :teams
	attr_accessor :inning_number, :inning_half
	
	def initialize
		@teams = Array.new(2)
	end
end

#
#  Team info class
#
class Team
	attr_accessor :name, :runs, :hits, :errors
	
	def initialize
	end
end

#
# MLB agent class
#
class MlbAgent
	attr_accessor :url, :xml_data, :xml_doc, :games
	
	def initialize(date=Time.now)
		# build the mlb stats url for today
		build_url(date)
		
		# fetch the mlb xml data
		@xml_data = fetch_xml_data()
		
		# parse the data into an xml document
		@xml_doc = parse_xml(@xml_data)
	end
	
	def build_url(date)
		# create the url components
		#url_year = 'year_2011'
		#url_month = 'month_09'
		#url_day = 'day_03'
		url_year = "year_%04d" % date.year
		url_month = "month_%02d" % date.month
		url_day = "day_%02d" % date.day
		
		# build the url
		@url = "http://gd2.mlb.com/components/game/mlb/#{url_year}/#{url_month}/#{url_day}/scoreboard.xml"
		
		# write the url to the console
		puts "MLB url used = #{@url}"
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
			
			#
			# Populate the game object
			#
			
			# get the game attributes
			game_attributes = game_element.elements['game'].attributes
			
			# set the game id
			game.id = game_attributes['id']
			
			# set the game status
			game.status = game_attributes['status']
			
			# set the game start time
			game.start_time = game_attributes['start_time']
			
			# set the game delay reason (if given)
			game.delay_reason = game_attributes['delay_reason']
			
			# spin through each team element
			game_element.elements.each_with_index('team') do |team_element, index|
				# only process two team elements
				if (index < 2)
					# create a new team object
					team = game.teams[index] = Team.new
					
					# set the team name
					team.name = team_element.attributes['name']
					
					# set the number of runs scored by the team
					team.runs = team_element.elements['gameteam'].attributes['R']
					
					# set the number of hits made by the team
					team.hits = team_element.elements['gameteam'].attributes['H']
					
					# set the number of errors made by the team
					team.errors = team_element.elements['gameteam'].attributes['E']
				end
			end
			
			# get the inning element (only available when game is in-progress)
			inning_element = game_element.elements['inningnum']
			
			# if the inning element is given
			if inning_element
				# get the inning number
				inning_number = inning_element.attributes['inning']
				
				# get the inning number
				if inning_element.attributes['half'] == 'B'
					game.inning_half = 'Bottom'
				else
					game.inning_half = 'Top'
				end
				
				# get the last number of the inning (as a character)
				last_inning_number_char = inning_number.to_a[-1]
				if (last_inning_number_char == "1")
					game.inning_number = "#{inning_number}st"
				elsif (last_inning_number_char == "2")
					game.inning_number = "#{inning_number}nd"
				elseif (last_inning_number_char == "3")
					game.inning_number = "#{inning_number}rd"
				else
					game.inning_number = "#{inning_number}th"
				end
			end
			
			# add the game object to the game array
			games << game
		end
	end
end

#
# Game object array exporter class
#
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
				# build the rss title string
				rss_title = game.teams[0].name + " vs " + game.teams[1].name +
					"  (Starts " + game.start_time + ")";
			elsif ((status == "FINAL") || (status == "GAME_OVER"))
				# build the rss title string
				rss_title = game.teams[0].name + " " + game.teams[0].runs + '  ' +
					game.teams[1].name + " " + game.teams[1].runs +
					"  (FINAL)";
			elsif ((status == "DELAYED") || (status == "OTHER"))
				# build the rss title string
				rss_title = game.teams[0].name + " vs " + game.teams[1].name +
                "  (" + game.delay_reason + ")"
			elsif (status == "IN_PROGRESS")
				# build the rss title string
        rssTitle = game.teams[0].name + " " + game.teams[0].runs + "  " +
                game.teams[1].name + " " + game.teams[1].runs +
                "  (" + game.inning_half + " of the " +
                game.inning_num + ")";
			else
				# build the rss title string
				rss_title = game.teams[0].name + " vs " + game.teams[1].name +
					"  (Starts " + game.start_time + ")";
			end
			
			# add the rss game entry
			rss = rss + "<item><title>" + rss_title + "</title></item>\n"
		end

		# add the rss footer
		rss = rss + "</channel></rss>"
	end
end
