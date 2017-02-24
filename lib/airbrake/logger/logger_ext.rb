##
# Redefine +Logger+ from stdlib, so it can both log and report errors to
# Airbrake.
#
# @example
#   # Create a logger like you normally do.
#   logger = Logger.new(STDOUT)
#
#   # Assign a default Airbrake notifier
#   logger.airbrake = Airbrake[:default]
#
#   # Just use the logger like you normally do.
#   logger.fatal('oops')
class Logger
  # Store the orginal methods to use them later.
  alias add_without_airbrake add
  alias initialize_without_airbrake initialize

  ##
  # @see https://goo.gl/MvlYq3 Logger#initialize
  def initialize(*args)
    @airbrake = Airbrake[:default]
    @airbrake_severity_level = WARN
    initialize_without_airbrake(*args)
  end

  ##
  # @return [Airbrake::Notifier] notifier to be used to send notices
  attr_accessor :airbrake

  ##
  # @example
  #   logger.airbrake_severity_level = Logger::FATAL
  # @return [Integer] the level that c
  attr_accessor :airbrake_severity_level

  ##
  # @see https://goo.gl/8zPyoM Logger#add
  def add(severity, message = nil, progname = nil)
    if severity >= airbrake_severity_level && airbrake
      notify_airbrake(severity, message || progname)
    end
    add_without_airbrake(severity, message, progname)
  end

  private

  def notify_airbrake(severity, message)
    notice = Airbrake.build_notice(message)

    # Get rid of unwanted internal Logger frames.
    # Example: /ruby-2.4.0/lib/ruby/2.4.0/logger.rb
    notice[:errors].first[:backtrace].shift

    notice[:context][:component] = 'log'
    notice[:context][:severity] = airbrake_severity(severity)

    Airbrake.notify(notice)
  end

  def airbrake_severity(severity)
    (case severity
     when DEBUG
       'debug'
     when INFO
       'info'
     when WARN
       'warning'
     when ERROR, UNKNOWN
       'error'
     when FATAL
       'critical'
     end).freeze
  end
end
