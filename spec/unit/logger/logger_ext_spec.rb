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

  let(:logger) { Logger.new('/dev/null') }

  def wait_for_a_request_with_body(body)
    wait_for(a_request(:post, endpoint).with(body: body)).to have_been_made.once
  end

  before do
    stub_request(:post, endpoint).to_return(status: 201, body: '{}')
  end

  describe "#airbrake" do
    it "has the default notifier installed by default" do
      expect(logger.airbrake).to be_an(Airbrake::Notifier)
    end

    it "installs Airbrake notifier" do
      notifier_id = airbrake.object_id
      expect(logger.airbrake.object_id).not_to eq(notifier_id)

      logger.airbrake = airbrake
      expect(logger.airbrake.object_id).to eq(notifier_id)
    end
  end

  context "when Airbrake is installed" do
    let(:out) { StringIO.new }
    let(:logger) { Logger.new(out) }

    before do
      logger.airbrake = airbrake
    end

    it "both logs and notifies" do
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
      wait_for_a_request_with_body(/"component":"log"/)
    end

    it "strips out internal logger frames" do
      logger.fatal('bongo')

      wait_for(
        a_request(:post, endpoint).
        with(body: %r{"file":".+/logger.rb"})
      ).not_to have_been_made
    end
  end

  describe "#airbrake_severity_level" do
    context "when not set" do
      it "defaults to Logger::WARN" do
        expect(logger.airbrake_severity_level).to eq(Logger::WARN)
      end
    end

    context "when set" do
      before do
        logger.airbrake_severity_level = Logger::FATAL
      end

      it "does not notify below the specified level" do
        logger.error('bingo')
        wait_for(a_request(:post, endpoint)).not_to have_been_made
      end

      it "notifies in the current or above level" do
        logger.fatal('bingo')
        wait_for(a_request(:post, endpoint)).to have_been_made
      end
    end
  end

  context "when Airbrake is not installed" do
    it "only logs, never notifies" do
      out = StringIO.new
      l = Logger.new(out)
      msg = 'bango'

      l.fatal(msg)

      wait_for(a_request(:post, endpoint)).not_to have_been_made
      expect(out.string).to match('FATAL -- : bango')
    end
  end
end
