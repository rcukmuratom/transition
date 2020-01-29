# Original code (MIT) can be found here https://github.com/jpastuszek/iis-access-log-parser
# Deciding not to fork it and host it on a gemserver given this specific
# permutation will only live for a short time until UKRI transition is complete.

require 'rails_helper'

describe Transition::Import::IISAccessLogParser::Entry do
  it "can be constructed from string" do
    described_class.from_string("2011-06-20 00:00:00 38.111.242.43 GET /SharedControls/getListingThumbs.aspx img=48,13045,27801,25692,35,21568,21477,21477,10,18,46,8&premium=0|1|0|0|0|0|0|0|0|0|0|0&h=100&w=125&pos=175&scale=true 80 - 92.20.10.104 Mozilla/4.0+(compatible;+MSIE+8.0;+Windows+NT+6.1;+Trident/4.0;+GTB6.6;+SLCC2;+.NET+CLR+2.0.50727;+.NET+CLR+3.5.30729;+.NET+CLR+3.0.30729;+Media+Center+PC+6.0;+aff-kingsoft-ciba;+.NET4.0C;+MASN;+AskTbSTC/5.8.0.12304) - 200 0 0 609")

    described_class.from_string("2011-06-20 00:00:00 38.111.242.43 GET /SharedControls/getListingThumbs.aspx img=48,13045,27801,25692,35,21568,21477,21477,10,18,46,8&premium=0|1|0|0|0|0|0|0|0|0|0|0&h=100&w=125&pos=175&scale=true 80 - 92.20.10.104 Mozilla/4.0+(compatible;+MSIE+8.0;+Windows+NT+6.1;+Trident/4.0;+GTB6.6;+SLCC2;+.NET+CLR+2.0.50727;+.NET+CLR+3.5.30729;+.NET+CLR+3.0.30729;+Media+Center+PC+6.0;+aff-kingsoft-ciba;+.NET4.0C;+MASN;+AskTbSTC/5.8.0.12304) - 200 0 0 609 test oter now")

    #lambda{ IISAccessLogParser::Entry.from_string("2011-06-20 00:00:00 38.111.242.43 GET /SharedControls/getListingThumbs.aspx img=48,13045,27801,25692,35,21568,21477,21477,10,18,46,8&premium=0|1|0|0|0|0|0|0|0|0|0|0&h=100&w=125&pos=175&scale=true 80 - 92.20.10.104 Mozilla/4.0+(compatible;+MSIE+8.0;+Windows+NT+6.1;+Trident/4.0;+GTB6.6;+SLCC2;+.NET+CLR+2.0.50727;+.NET+CLR+3.5.30729;+.NET+CLR+3.0.30729;+Media+Center+PC+6.0;+aff-kingsoft-ciba;+.NET4.0C;+MASN;+AskTbSTC/5.") }.should raise_error ArgumentError
  end

  it "should contain properly parsed date types" do
    e = described_class.from_string("2019-12-17 15:11:25 149.155.50.65 GET /news/ - 80 - 192.171.180.236 Mozilla/5.0+(Windows+NT+6.1;+Win64;+x64)+AppleWebKit/537.36+(KHTML,+like+Gecko)+Chrome/76.0.3809.132+Safari/537.36 http://dev.infohub.ukri.org/our-ukri/ dev.infohub.ukri.org 200 0 0 368")

    e.date.should be_kind_of Time
    e.date.day.should eql 17
    e.date.month.should eql 12
    e.date.year.should eql 2019
    e.date.hour.should eql 15
    e.date.min.should eql 11
    e.date.sec.should eql 25
    e.date.zone.should eql 'GMT'

    e.server_ip.should be_kind_of IP::V4
    e.client_ip.should be_kind_of IP::V4

    e.port.should be_kind_of Integer
    e.status.should be_kind_of Integer
    e.substatus.should be_kind_of Integer
    e.win32_status.should be_kind_of Integer

    e.time_taken.should be_kind_of Float
    e.time_taken.should eql 0.368

    e.username.should be_nil

    e.user_agent.should eql "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.132 Safari/537.36"
    e.user_referer.should eql "http://dev.infohub.ukri.org/our-ukri/"
  end

  it "should handle correctly nil useragent" do
    e = described_class.from_string("2011-06-20 00:01:02 38.111.242.43 GET /SharedControls/getListingThumbs.aspx img=48,13045,27801,25692,35,21568,21477,21477,10,18,46,8&premium=0|1|0|0|0|0|0|0|0|0|0|0&h=100&w=125&pos=175&scale=true 80 - 92.20.10.104 - 200 0 0 609 test oter now")

    e.user_agent.should be_nil
  end

  it "should handle strings containing invalid UTF-8 bytes" do
    # `/xE4` is an invalid UTF-8 byte in the query string
    invalid_line = "2019-12-17 15:11:25 149.155.50.65 GET /news?q=char\xE4 - 80 - 192.171.180.236 Mozilla http://dev.infohub.ukri.org/our-ukri/ dev.infohub.ukri.org 200 0 0 368"
    e = described_class.from_string(invalid_line)
    # It's replaced during parsing with `\uFFFD`, the standard replacement
    # character: https://www.fileformat.info/info/unicode/char/fffd/index.htm
    e.url.should == "/news?q=char\uFFFD"
  end
end

describe Transition::Import::IISAccessLogParser do
  it "should read entries for IO" do
    last = nil
    File.open('spec/fixtures/hits/iis_w3c_example.log', 'r') do |io|
      described_class.new(io) do |entry|
        last = entry
      end
    end

    last.url.should == '/news/'
  end

  it "should allow reading entries from file" do
    last = nil
    described_class.from_file('spec/fixtures/hits/iis_w3c_example.log') do |entry|
      last = entry
    end

    last.url.should == '/news/'
  end
end
