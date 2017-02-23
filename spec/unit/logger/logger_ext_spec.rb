require 'spec_helper'

RSpec.describe Logger do
  let(:project_id) { 113743 }
  let(:project_key) { 'fd04e13d806a90f96614ad8e529b2822' }

  let(:endpoint) do
    "https://airbrake.io/api/v3/projects/#{project_id}/notices?key=#{project_key}"
  end

  let(:airbrake) do
    Airbrake::Notifier.new(project_id: project_id, project_key: project_key)
  end

  def wait_for_a_request_with_body(body)
    wait_for(a_request(:post, endpoint).with(body: body)).to have_been_made.once
  end

  before do
    stub_request(:post, endpoint).to_return(status: 201, body: '{}')
  end

  describe "#airbrake" do
    it "installs Airbrake notifier" do
      l = Logger.new('/dev/null')
      expect(l.airbrake).to be_nil

      l.airbrake = airbrake
      expect(l.airbrake).to be_an(Airbrake::Notifier)
    end
  end

  context "when Airbrake is installed" do
    let(:out) { StringIO.new }
    let(:logger) { Logger.new(out) }

    before do
      logger.airbrake = airbrake
    end

    it "both logs and notifies with the correct severity" do
      msg = 'bingo'
      logger.fatal(msg)

      wait_for_a_request_with_body(/"message":"#{msg}"/)
      expect(out.string).to match(/FATAL -- : #{msg}/)
    end

    it "sets the correct severity" do
      logger.fatal('bango')
      wait_for_a_request_with_body(/"context":{.*"severity":"critical".*}/)
    end

    it "sets the correct component" do
      logger.fatal('bingo')
      wait_for_a_request_with_body(/"component":"logger"/)
    end

    it "strips out internal logger frames" do
      logger.fatal('bongo')

      wait_for(
        a_request(:post, endpoint).
        with(body: %r{"file":".+/logger.rb"})
      ).not_to have_been_made
    end
  end

  context "when Airbrake is not installed" do
    it "only logs, never notifies" do
      out = StringIO.new
      l = Logger.new(out)
      msg = 'bango'

      l.debug(msg)

      wait_for(a_request(:post, endpoint)).not_to have_been_made
      expect(out.string).to match('DEBUG -- : bango')
    end
  end
end
