module MyIntervention

  def self.on_request t
    puts "YAY IM POSITIVE!" if t.request.headers.uri.query[/&sentiment=(\w+)&?/, 1] == "positive" if t.request.headers.uri.query
  end

  def self.on_response t
    if t.request.headers.uri.path == "newapi.int.brandwatch.com/projects/38610656/data/mentions"
      sentiment = t.request.headers.uri.query[/&sentiment=(\w+)&?/, 1]
      # puts JSON.pretty_generate JSON.parse t.response.body.content

      mes = @header + @mention + @footer
      mes.sub! /"sentiment": "\w+",/, "\"sentiment\": \"#{sentiment}\"," unless sentiment.nil?
      t.response.body.content = mes
    end
  end


  @header = '
  {
  "resultsTotal": 1,
  "resultsPage": 0,
  "resultsPageSize": 20,
  "results": [
  '

  @footer = '
    ]
  }
  '

  @mention = '
  {
      "accountType": null,
      "assignment": null,
      "author": "Zack Bleach is a dude!!",
      "avatarUrl": null,
      "averageDurationOfVisit": 5,
      "averageVisits": 2,
      "backlinks": 39550,
      "blogComments": null,
      "categories": [

      ],
      "checked": false,
      "city": null,
      "cityCode": "",
      "continent": "Europe",
      "continentCode": "eu",
      "country": "Republic of Ireland",
      "countryCode": "ie",
      "county": null,
      "countyCode": "",
      "date": "2013-09-13T09:00:00.000+0000",
      "displayUrls": null,
      "domain": "www.pistonheads.com",
      "editorialValueEUR": null,
      "editorialValueGBP": null,
      "editorialValueUSD": null,
      "expandedUrls": null,
      "facebookAuthorId": null,
      "facebookComments": null,
      "facebookLikes": null,
      "facebookRole": null,
      "facebookShares": null,
      "facebookSubtype": null,
      "forumPosts": 15,
      "forumViews": null,
      "gender": null,
      "id": 2760067154,
      "impact": 59,
      "importanceAmplification": 76,
      "importanceReach": 42,
      "impressions": null,
      "influence": null,
      "interest": null,
      "language": "en",
      "latitude": null,
      "longitude": null,
      "matchPositions": [
        {
          "start": 49,
          "text": "Marmite",
          "length": 7
        }
      ],
      "monthlyVisitors": 270000,
      "mozRank": 5.82,
      "noteIds": [

      ],
      "outreach": null,
      "pageType": "forum",
      "pagesPerVisit": 4,
      "percentFemaleVisitors": 41,
      "percentMaleVisitors": 59,
      "primaryCity": null,
      "primaryCityCode": "",
      "primaryContinent": "Europe",
      "primaryContinentCode": "eu",
      "primaryCountry": "Republic of Ireland",
      "primaryCountryCode": "ie",
      "primaryCounty": null,
      "primaryCountyCode": "",
      "primaryLocation": "eu,ie,,,",
      "primaryState": null,
      "primaryStateCode": "",
      "priority": null,
      "professions": [

      ],
      "queryId": 72838858,
      "queryName": "Marmite",
      "reach": null,
      "replyTo": null,
      "resourceType": "pistonheadsForum",
      "retweetOf": null,
      "sentiment": "neutral",
      "shortUrls": null,
      "snippet": "We are in your snippit interveaning with your shit!",
      "starred": false,
      "state": null,
      "stateCode": "",
      "status": null,
      "tags": [

      ],
      "threadAuthor": null,
      "threadCreated": null,
      "threadEntryType": null,
      "threadId": 2760067118,
      "threadURL": null,
      "title": "RE: BMW M135i vs Renaultsport Megane 265 - PistonHeads",
      "trackedLinkClicks": null,
      "trackedLinks": null,
      "twitterAuthorId": null,
      "twitterFollowers": 100,
      "twitterFollowing": 200,
      "twitterPostCount": 300,
      "twitterReplyCount": null,
      "twitterRetweets": null,
      "twitterRole": null,
      "twitterVerified": null,
      "url": "http://www.pistonheads.com/gassing/topic.asp?h=0&t=1330307&mid=0&nmt=RE%3A+BMW+M135i+vs+Renaultsport+Megane+265#message12",
      "wordCount": null
    }
    '

end