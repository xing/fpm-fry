require 'json'
describe "docker_build" do

  describe "result parsing" do
=begin
    let(:result) do
[
"{\"stream\":\"Step 0 : FROM ubuntu:precise\\n\"}\r\n",
"{\"stream\":\" ---\\u003e 9cd978db300e\\n\"}\r\n",
"{\"stream\":\"Step 1 : ADD . /tmp/build\\n\"}\r\n",
"{\"stream\":\" ---\\u003e 7bbd7692593b\\n\"}\r\n",
"{\"stream\":\"Step 2 : WORKDIR /tmp/build\\n\"}\r\n",
"{\"stream\":\" ---\\u003e Running in 6e61d8cb97c6\\n\"}\r\n",
"{\"stream\":\" ---\\u003e 01428e0aa31d\\n\"}\r\n",
"{\"stream\":\"Step 3 : CMD /tmp/build/.build.sh\\n\"}\r\n",
"{\"stream\":\" ---\\u003e Running in b5072dabcd39\\n\"}\r\n",
"{\"stream\":\" ---\\u003e 774354c23bd9\\n\"}\r\n",
"{\"stream\":\"Successfully built 774354c23bd9\\n\"}\r\n"
]
    end

    it "works" do
      result.each do |b|
        l = JSON.load(b)
        puts l.inspect
      end
    end
=end
  end
end
